import Foundation
import Security
import SwiftData

enum FinanceCloudConfiguration {
    static let projectURL = URL(string: "https://bgpjpimhrnmthamzqsgv.supabase.co")!
    static let publishableKey = "sb_publishable_Y6P3ePpdP3hDlwvBuxpSkQ_ec1LNexw"
    static let workspaceID = UUID(uuidString: "0db2b4f5-ff7c-4fbd-b71b-e2ddf9d5def6")!
    static let emailDefaultsKey = "financeCloud.email"
}

@MainActor
final class FinanceCloud: ObservableObject {
    static let shared = FinanceCloud()

    @Published private(set) var isSignedIn = false
    @Published private(set) var isBusy = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var savedEmail: String

    private let keychain = FinanceKeychain()
    private let defaults: UserDefaults
    private var accessToken: String?
    private var tokenRefreshTask: Task<String, Error>?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        savedEmail = defaults.string(forKey: FinanceCloudConfiguration.emailDefaultsKey) ?? ""
        accessToken = keychain.read("access_token")
        isSignedIn = accessToken != nil || keychain.read("refresh_token") != nil
    }

    func signIn(email: String, password: String) async {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        statusMessage = nil
        do {
            let session = try await authenticate(email: email, password: password)
            try await verifyWorkspaceAccess(token: session.accessToken)
            accessToken = session.accessToken
            keychain.write(session.accessToken, key: "access_token")
            if let refreshToken = session.refreshToken {
                keychain.write(refreshToken, key: "refresh_token")
            }
            defaults.set(email, forKey: FinanceCloudConfiguration.emailDefaultsKey)
            savedEmail = email
            isSignedIn = true
            statusMessage = "Signed in."
        } catch {
            accessToken = nil
            keychain.delete("access_token")
            keychain.delete("refresh_token")
            isSignedIn = false
            statusMessage = error.localizedDescription
        }
    }

    func signOut() {
        tokenRefreshTask?.cancel()
        tokenRefreshTask = nil
        accessToken = nil
        isSignedIn = false
        statusMessage = "Signed out. The copy on this phone is unchanged."
        keychain.delete("access_token")
        keychain.delete("refresh_token")
    }

    /// Pushes dirty local rows and applies newer remote rows. Signed-out
    /// launches do nothing. A failed upload leaves those rows unsynced so the
    /// next refresh retries them without dropping the local copy.
    func sync(in context: ModelContext) async {
        guard !isBusy else { return }
        guard isSignedIn else { return }
        isBusy = true
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer {
            context.autosaveEnabled = autosave
            isBusy = false
        }

        do {
            NetIncomeManager.shared.flushPendingSave()
            let token = try await validAccessToken()
            try await verifyWorkspaceAccess(token: token)
            var uploaded = 0
            var downloaded = 0

            let cashFlow = try await syncCashFlow(token: token, context: context)
            uploaded += cashFlow.uploaded
            downloaded += cashFlow.downloaded

            let predefined = try await syncPredefined(token: token, context: context)
            uploaded += predefined.uploaded
            downloaded += predefined.downloaded

            let quickAdd = try await syncQuickAdd(token: token, context: context)
            uploaded += quickAdd.uploaded
            downloaded += quickAdd.downloaded

            let transactions = try await syncTransactions(token: token, context: context)
            uploaded += transactions.uploaded
            downloaded += transactions.downloaded

            let income = try await syncNetIncome(token: token, context: context)
            uploaded += income.uploaded
            downloaded += income.downloaded

            if uploaded == 0 && downloaded == 0 {
                statusMessage = "Cloud data is up to date."
            } else {
                statusMessage = "Sync complete: \(uploaded) uploaded, \(downloaded) downloaded."
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    // MARK: - Tables

    private func syncCashFlow(token: String, context: ModelContext) async throws -> SyncCounts {
        let remote = try await fetchAll(
            table: "finance_cash_flow_items",
            select: "id,name,amount,is_owed_to_me,is_settled,updated_at,deleted_at",
            token: token,
            as: CashFlowCloudRow.self
        )
        let local = try context.fetch(FetchDescriptor<CashFlowItem>())
        var byID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let remoteIDs = Set(remote.map(\.id))
        var counts = SyncCounts()
        var pending: [CashFlowItem] = []

        for row in remote {
            if let item = byID[row.id] {
                switch cloudMergeAction(localUpdatedAt: item.updatedAt, lastSyncedAt: item.lastSyncedAt, remoteUpdatedAt: row.updatedAt) {
                case .applyRemote:
                    item.name = row.name
                    item.amount = row.amount.value
                    item.isOwedToMe = row.isOwedToMe
                    item.isSettled = row.isSettled
                    item.deletedAt = row.deletedAt
                    item.updatedAt = row.updatedAt
                    item.lastSyncedAt = row.updatedAt
                    counts.downloaded += 1
                case .uploadLocal:
                    pending.append(item)
                case .leave:
                    break
                }
            } else {
                let item = CashFlowItem(
                    id: row.id,
                    name: row.name,
                    amount: row.amount.value,
                    isOwedToMe: row.isOwedToMe,
                    isSettled: row.isSettled,
                    updatedAt: row.updatedAt,
                    deletedAt: row.deletedAt,
                    lastSyncedAt: row.updatedAt
                )
                context.insert(item)
                byID[row.id] = item
                counts.downloaded += 1
            }
        }
        pending.append(contentsOf: local.filter { !remoteIDs.contains($0.id) })
        try context.save()
        counts.uploaded += try await upload(pending, table: "finance_cash_flow_items", token: token, context: context) { item in
            [
                "id": item.id.uuidString.lowercased(),
                "workspace_id": FinanceCloudConfiguration.workspaceID.uuidString.lowercased(),
                "name": item.name ?? NSNull(),
                "amount": item.amount,
                "is_owed_to_me": item.isOwedToMe,
                "is_settled": item.isSettled,
                "updated_at": SupabaseTimestamp.format(item.updatedAt),
                "deleted_at": item.deletedAt.map(SupabaseTimestamp.format) ?? NSNull()
            ]
        }
        return counts
    }

    private func syncPredefined(token: String, context: ModelContext) async throws -> SyncCounts {
        let remote = try await fetchAll(
            table: "finance_predefined_transactions",
            select: "id,description,amount,day_of_week,is_income,updated_at,deleted_at",
            token: token,
            as: TemplateCloudRow.self
        )
        let local = try context.fetch(FetchDescriptor<PredefinedTransaction>())
        var byID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let remoteIDs = Set(remote.map(\.id))
        var counts = SyncCounts()
        var pending: [PredefinedTransaction] = []

        for row in remote {
            if let item = byID[row.id] {
                switch cloudMergeAction(localUpdatedAt: item.updatedAt, lastSyncedAt: item.lastSyncedAt, remoteUpdatedAt: row.updatedAt) {
                case .applyRemote:
                    item.desc = row.description
                    item.amount = row.amount.value
                    item.dayOfWeek = row.dayOfWeek
                    item.isIncome = row.isIncome
                    item.deletedAt = row.deletedAt
                    item.updatedAt = row.updatedAt
                    item.lastSyncedAt = row.updatedAt
                    counts.downloaded += 1
                case .uploadLocal:
                    pending.append(item)
                case .leave:
                    break
                }
            } else {
                let item = PredefinedTransaction(
                    id: row.id,
                    desc: row.description,
                    amount: row.amount.value,
                    dayOfWeek: row.dayOfWeek,
                    isIncome: row.isIncome,
                    updatedAt: row.updatedAt,
                    deletedAt: row.deletedAt,
                    lastSyncedAt: row.updatedAt
                )
                context.insert(item)
                byID[row.id] = item
                counts.downloaded += 1
            }
        }
        pending.append(contentsOf: local.filter { !remoteIDs.contains($0.id) })
        try context.save()
        counts.uploaded += try await upload(pending, table: "finance_predefined_transactions", token: token, context: context) { item in
            [
                "id": item.id.uuidString.lowercased(),
                "workspace_id": FinanceCloudConfiguration.workspaceID.uuidString.lowercased(),
                "description": item.desc ?? NSNull(),
                "amount": item.amount,
                "day_of_week": item.dayOfWeek ?? NSNull(),
                "is_income": item.isIncome,
                "updated_at": SupabaseTimestamp.format(item.updatedAt),
                "deleted_at": item.deletedAt.map(SupabaseTimestamp.format) ?? NSNull()
            ]
        }
        return counts
    }

    private func syncQuickAdd(token: String, context: ModelContext) async throws -> SyncCounts {
        let remote = try await fetchAll(
            table: "finance_quick_add_transactions",
            select: "id,description,amount,is_income,updated_at,deleted_at",
            token: token,
            as: QuickAddCloudRow.self
        )
        let local = try context.fetch(FetchDescriptor<QuickAddTransaction>())
        var byID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let remoteIDs = Set(remote.map(\.id))
        var counts = SyncCounts()
        var pending: [QuickAddTransaction] = []

        for row in remote {
            if let item = byID[row.id] {
                switch cloudMergeAction(localUpdatedAt: item.updatedAt, lastSyncedAt: item.lastSyncedAt, remoteUpdatedAt: row.updatedAt) {
                case .applyRemote:
                    item.desc = row.description
                    item.amount = row.amount.value
                    item.isIncome = row.isIncome
                    item.deletedAt = row.deletedAt
                    item.updatedAt = row.updatedAt
                    item.lastSyncedAt = row.updatedAt
                    counts.downloaded += 1
                case .uploadLocal:
                    pending.append(item)
                case .leave:
                    break
                }
            } else {
                let item = QuickAddTransaction(
                    id: row.id,
                    desc: row.description,
                    amount: row.amount.value,
                    isIncome: row.isIncome,
                    updatedAt: row.updatedAt,
                    deletedAt: row.deletedAt,
                    lastSyncedAt: row.updatedAt
                )
                context.insert(item)
                byID[row.id] = item
                counts.downloaded += 1
            }
        }
        pending.append(contentsOf: local.filter { !remoteIDs.contains($0.id) })
        try context.save()
        counts.uploaded += try await upload(pending, table: "finance_quick_add_transactions", token: token, context: context) { item in
            [
                "id": item.id.uuidString.lowercased(),
                "workspace_id": FinanceCloudConfiguration.workspaceID.uuidString.lowercased(),
                "description": item.desc ?? NSNull(),
                "amount": item.amount,
                "is_income": item.isIncome,
                "updated_at": SupabaseTimestamp.format(item.updatedAt),
                "deleted_at": item.deletedAt.map(SupabaseTimestamp.format) ?? NSNull()
            ]
        }
        return counts
    }

    private func syncTransactions(token: String, context: ModelContext) async throws -> SyncCounts {
        let remote = try await fetchAll(
            table: "finance_transactions",
            select: "id,description,amount,day_of_week,is_completed,is_income,updated_at,deleted_at",
            token: token,
            as: TransactionCloudRow.self
        )
        let local = try context.fetch(FetchDescriptor<Transaction>())
        var byID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let remoteIDs = Set(remote.map(\.id))
        var counts = SyncCounts()
        var pending: [Transaction] = []
        var balanceDelta = 0.0

        for row in remote {
            if let item = byID[row.id] {
                switch cloudMergeAction(localUpdatedAt: item.updatedAt, lastSyncedAt: item.lastSyncedAt, remoteUpdatedAt: row.updatedAt) {
                case .applyRemote:
                    balanceDelta += transactionBalanceDelta(
                        oldAmount: item.amount,
                        oldIsIncome: item.isIncome,
                        oldIsDeleted: item.deletedAt != nil,
                        newAmount: row.amount.value,
                        newIsIncome: row.isIncome,
                        newIsDeleted: row.deletedAt != nil
                    )
                    item.desc = row.description
                    item.amount = row.amount.value
                    item.dayOfWeek = row.dayOfWeek
                    item.isCompleted = row.isCompleted
                    item.isIncome = row.isIncome
                    item.deletedAt = row.deletedAt
                    item.updatedAt = row.updatedAt
                    item.lastSyncedAt = row.updatedAt
                    counts.downloaded += 1
                case .uploadLocal:
                    pending.append(item)
                case .leave:
                    break
                }
            } else {
                let item = Transaction(
                    id: row.id,
                    desc: row.description,
                    amount: row.amount.value,
                    dayOfWeek: row.dayOfWeek,
                    isCompleted: row.isCompleted,
                    isIncome: row.isIncome,
                    updatedAt: row.updatedAt,
                    deletedAt: row.deletedAt,
                    lastSyncedAt: row.updatedAt
                )
                context.insert(item)
                byID[row.id] = item
                balanceDelta += transactionBalanceContribution(
                    amount: item.amount,
                    isIncome: item.isIncome,
                    isDeleted: item.deletedAt != nil
                )
                counts.downloaded += 1
            }
        }
        pending.append(contentsOf: local.filter { !remoteIDs.contains($0.id) })
        if balanceDelta != 0 {
            NetIncomeManager.shared.applyRemoteTransactionDelta(balanceDelta)
        }
        try context.save()
        counts.uploaded += try await upload(pending, table: "finance_transactions", token: token, context: context) { item in
            [
                "id": item.id.uuidString.lowercased(),
                "workspace_id": FinanceCloudConfiguration.workspaceID.uuidString.lowercased(),
                "description": item.desc ?? NSNull(),
                "amount": item.amount,
                "day_of_week": item.dayOfWeek ?? NSNull(),
                "is_completed": item.isCompleted,
                "is_income": item.isIncome,
                "updated_at": SupabaseTimestamp.format(item.updatedAt),
                "deleted_at": item.deletedAt.map(SupabaseTimestamp.format) ?? NSNull()
            ]
        }
        return counts
    }

    private func syncNetIncome(token: String, context: ModelContext) async throws -> SyncCounts {
        let remote = try await fetchAll(
            table: "finance_net_income",
            select: "id,value,updated_at,deleted_at",
            token: token,
            as: NetIncomeCloudRow.self
        )
        let local = try context.fetch(FetchDescriptor<NetIncomeEntity>())
        var byID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let remoteIDs = Set(remote.map(\.id))
        var counts = SyncCounts()
        var pending: [NetIncomeEntity] = []
        var appliedRemote = false

        for row in remote {
            if let item = byID[row.id] {
                switch cloudMergeAction(localUpdatedAt: item.updatedAt, lastSyncedAt: item.lastSyncedAt, remoteUpdatedAt: row.updatedAt) {
                case .applyRemote:
                    item.value = row.value.value
                    item.deletedAt = row.deletedAt
                    item.updatedAt = row.updatedAt
                    item.lastSyncedAt = row.updatedAt
                    appliedRemote = true
                    counts.downloaded += 1
                case .uploadLocal:
                    pending.append(item)
                case .leave:
                    break
                }
            } else {
                let item = NetIncomeEntity(
                    id: row.id,
                    value: row.value.value,
                    updatedAt: row.updatedAt,
                    deletedAt: row.deletedAt,
                    lastSyncedAt: row.updatedAt
                )
                context.insert(item)
                byID[row.id] = item
                appliedRemote = true
                counts.downloaded += 1
            }
        }
        pending.append(contentsOf: local.filter { !remoteIDs.contains($0.id) })
        if appliedRemote {
            NetIncomeManager.shared.adoptStoredValue()
        }
        try context.save()
        counts.uploaded += try await upload(pending, table: "finance_net_income", token: token, context: context) { item in
            [
                "id": item.id.uuidString.lowercased(),
                "workspace_id": FinanceCloudConfiguration.workspaceID.uuidString.lowercased(),
                "value": item.value,
                "updated_at": SupabaseTimestamp.format(item.updatedAt),
                "deleted_at": item.deletedAt.map(SupabaseTimestamp.format) ?? NSNull()
            ]
        }
        return counts
    }

    private func upload<Record: FinanceSyncRecord>(
        _ records: [Record],
        table: String,
        token: String,
        context: ModelContext,
        body: (Record) -> [String: Any]
    ) async throws -> Int {
        var uploaded = 0
        for record in records {
            let stamp = record.updatedAt
            let savedAt = try await upsert(table: table, body: body(record), token: token)
            guard record.updatedAt == stamp else { continue }
            record.updatedAt = savedAt
            record.lastSyncedAt = savedAt
            uploaded += 1
            try context.save()
        }
        return uploaded
    }

    // MARK: - HTTP

    private func validAccessToken() async throws -> String {
        if let accessToken, Self.tokenIsUsable(accessToken) { return accessToken }
        if let tokenRefreshTask { return try await tokenRefreshTask.value }
        let task = Task { @MainActor in
            try await self.renewAccessToken()
        }
        tokenRefreshTask = task
        defer { tokenRefreshTask = nil }
        return try await task.value
    }

    private func renewAccessToken() async throws -> String {
        guard let refreshToken = keychain.read("refresh_token"), !refreshToken.isEmpty else {
            throw FinanceCloudError.notSignedIn
        }
        let url = Self.endpoint(path: "/auth/v1/token", query: [
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ])
        let body = try JSONEncoder().encode(["refresh_token": refreshToken])
        do {
            let session = try await authenticateSession(url: url, body: body)
            accessToken = session.accessToken
            keychain.write(session.accessToken, key: "access_token")
            if let rotated = session.refreshToken {
                keychain.write(rotated, key: "refresh_token")
            }
            isSignedIn = true
            return session.accessToken
        } catch {
            if case FinanceCloudError.requestFailed(let message) = error,
               message.localizedCaseInsensitiveContains("invalid")
                || message.localizedCaseInsensitiveContains("grant") {
                signOut()
                statusMessage = FinanceCloudError.notSignedIn.localizedDescription
            }
            throw error
        }
    }

    private static func tokenIsUsable(_ token: String) -> Bool {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return false }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = payload.count % 4
        if remainder > 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: payload),
              let fields = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let expiry = fields["exp"] as? Double else { return false }
        return expiry > Date().timeIntervalSince1970 + 60
    }

    private func authenticate(email: String, password: String) async throws -> AuthSession {
        let url = Self.endpoint(path: "/auth/v1/token", query: [
            URLQueryItem(name: "grant_type", value: "password")
        ])
        let body = try JSONEncoder().encode(["email": email, "password": password])
        return try await authenticateSession(url: url, body: body)
    }

    private func authenticateSession(url: URL, body: Data) async throws -> AuthSession {
        let data = try await send(url: url, method: "POST", body: body, token: nil)
        return try JSONDecoder().decode(AuthSession.self, from: data)
    }

    private func verifyWorkspaceAccess(token: String) async throws {
        let url = Self.endpoint(path: "/rest/v1/workspaces", query: [
            URLQueryItem(name: "select", value: "id"),
            URLQueryItem(name: "id", value: "eq.\(FinanceCloudConfiguration.workspaceID.uuidString.lowercased())")
        ])
        let data = try await send(url: url, method: "GET", body: nil, token: token)
        let rows = try JSONDecoder().decode([WorkspaceIDRow].self, from: data)
        guard rows.contains(where: { $0.id == FinanceCloudConfiguration.workspaceID }) else {
            throw FinanceCloudError.workspaceUnavailable
        }
    }

    private func fetchAll<Row: Decodable>(
        table: String,
        select: String,
        token: String,
        as type: Row.Type
    ) async throws -> [Row] {
        let pageSize = 1000
        var offset = 0
        var all: [Row] = []
        while true {
            let url = Self.endpoint(path: "/rest/v1/\(table)", query: [
                URLQueryItem(name: "select", value: select),
                URLQueryItem(name: "workspace_id", value: "eq.\(FinanceCloudConfiguration.workspaceID.uuidString.lowercased())"),
                URLQueryItem(name: "order", value: "id.asc"),
                URLQueryItem(name: "limit", value: String(pageSize)),
                URLQueryItem(name: "offset", value: String(offset))
            ])
            let data = try await send(url: url, method: "GET", body: nil, token: token)
            let page = try makeDecoder().decode([Row].self, from: data)
            all.append(contentsOf: page)
            if page.count < pageSize { break }
            offset += pageSize
        }
        return all
    }

    private func upsert(table: String, body: [String: Any], token: String) async throws -> Date {
        let url = Self.endpoint(path: "/rest/v1/\(table)", query: [
            URLQueryItem(name: "on_conflict", value: "id")
        ])
        let payload = try JSONSerialization.data(withJSONObject: body)
        let data = try await send(
            url: url,
            method: "POST",
            body: payload,
            token: token,
            prefer: "resolution=merge-duplicates,return=representation"
        )
        let rows = try makeDecoder().decode([UpdatedAtRow].self, from: data)
        guard let updatedAt = rows.first?.updatedAt else {
            throw FinanceCloudError.invalidResponse
        }
        return updatedAt
    }

    private func send(
        url: URL,
        method: String,
        body: Data?,
        token: String?,
        prefer: String? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(FinanceCloudConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FinanceCloudError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FinanceCloudError.requestFailed(Self.message(from: data, status: http.statusCode))
        }
        return data
    }

    private static func endpoint(path: String, query: [URLQueryItem]) -> URL {
        var components = URLComponents(url: FinanceCloudConfiguration.projectURL, resolvingAgainstBaseURL: false)!
        components.path = path
        components.queryItems = query
        return components.url!
    }

    private static func message(from data: Data, status: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let text = (json["error_description"] as? String)
                ?? (json["msg"] as? String)
                ?? (json["message"] as? String)
            if let text, !text.isEmpty { return text }
        }
        let raw = String(data: data, encoding: .utf8) ?? "HTTP \(status)"
        if raw.count > 300 { return String(raw.prefix(300)) }
        return raw
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = SupabaseTimestamp.parse(value) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid Supabase timestamp"
                )
            }
            return date
        }
        return decoder
    }
}

private struct SyncCounts {
    var uploaded = 0
    var downloaded = 0
}

private struct AuthSession: Decodable {
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

private struct WorkspaceIDRow: Decodable {
    let id: UUID
}

private struct UpdatedAtRow: Decodable {
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
    }
}

private struct JSONDouble: Decodable {
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            value = number
            return
        }
        if let text = try? container.decode(String.self), let number = Double(text) {
            value = number
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a number")
    }
}

private struct CashFlowCloudRow: Decodable {
    let id: UUID
    let name: String?
    let amount: JSONDouble
    let isOwedToMe: Bool
    let isSettled: Bool
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, amount
        case isOwedToMe = "is_owed_to_me"
        case isSettled = "is_settled"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

private struct TemplateCloudRow: Decodable {
    let id: UUID
    let description: String?
    let amount: JSONDouble
    let dayOfWeek: String?
    let isIncome: Bool
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, description, amount
        case dayOfWeek = "day_of_week"
        case isIncome = "is_income"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

private struct QuickAddCloudRow: Decodable {
    let id: UUID
    let description: String?
    let amount: JSONDouble
    let isIncome: Bool
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, description, amount
        case isIncome = "is_income"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

private struct TransactionCloudRow: Decodable {
    let id: UUID
    let description: String?
    let amount: JSONDouble
    let dayOfWeek: String?
    let isCompleted: Bool
    let isIncome: Bool
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, description, amount
        case dayOfWeek = "day_of_week"
        case isCompleted = "is_completed"
        case isIncome = "is_income"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

private struct NetIncomeCloudRow: Decodable {
    let id: UUID
    let value: JSONDouble
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, value
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

enum FinanceCloudError: LocalizedError {
    case notSignedIn
    case workspaceUnavailable
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in to Supabase first."
        case .workspaceUnavailable:
            return "This account does not have access to the shared workspace."
        case .invalidResponse:
            return "Supabase returned an invalid response. Local data was kept."
        case .requestFailed(let message):
            return "Supabase request failed: \(message)"
        }
    }
}

private struct FinanceKeychain {
    private let service = "com.MattChew.MyFinanceTracker.supabase"

    func write(_ value: String, key: String) {
        let data = Data(value.utf8)
        delete(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
