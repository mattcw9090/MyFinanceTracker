import Foundation
import Network
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
    /// Set only when sync needs a person: sign-in, a blocked account, or uploads that keep failing.
    @Published private(set) var syncNotice: FinanceSyncNotice?
    @Published private(set) var savedEmail: String

    private var consecutiveUploadFailures = 0

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
            statusMessage = nil
            consecutiveUploadFailures = 0
            syncNotice = nil
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
        statusMessage = nil
        consecutiveUploadFailures = 0
        syncNotice = nil
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
            try await performSync(in: context)
            recordSyncResult(nil)
        } catch {
            recordSyncResult(error)
        }
    }

    /// Records whether this attempt needs a prompt. Does not change which rows were saved.
    private func recordSyncResult(_ error: Error?) {
        let next = nextFinanceSyncNotice(
            isSignedIn: isSignedIn,
            error: error,
            consecutiveFailures: consecutiveUploadFailures,
            current: syncNotice
        )
        consecutiveUploadFailures = next.consecutiveFailures
        syncNotice = next.notice
    }

    /// Ticks one transaction in Supabase. Local completion and cash-flow rows
    /// arrive only from the pull afterwards. A failure leaves the phone's row unchanged.
    func completeTransaction(
        _ transaction: Transaction,
        addToCashFlow: Bool,
        additionalCost: Double,
        splitNames: [String]?,
        in context: ModelContext
    ) async throws {
        let online = await Self.networkIsOnline()
        guard shouldCompleteTransactionOnline(isSignedIn: isSignedIn, isOnline: online) else {
            throw FinanceCloudError.needsConnection
        }
        guard !transaction.isCompleted, transaction.deletedAt == nil else { return }

        let deadline = Date().addingTimeInterval(60)
        while isBusy {
            if Date() >= deadline { throw FinanceCloudError.needsConnection }
            try await Task.sleep(for: .milliseconds(50))
        }

        isBusy = true
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer {
            context.autosaveEnabled = autosave
            isBusy = false
        }

        do {
            try await pushTransactionIfNeeded(transaction, context: context)
            let token = try await validAccessToken()
            try await invokeCompleteFinanceTransaction(
                id: transaction.id,
                addToCashFlow: addToCashFlow,
                additionalCost: additionalCost,
                splitNames: splitNames,
                token: token
            )
        } catch {
            throw FinanceCloudError.needsConnection
        }

        do {
            try await performSync(in: context)
        } catch {
            throw FinanceCloudError.completionNotDownloaded
        }
    }

    /// Reads one week's coaching sessions. Does not insert transactions or change net income.
    func previewCoachingSessions(weekStart: Date) async throws -> [CoachingSessionPreview] {
        try await prepareCoachingImport()
        do {
            let token = try await validAccessToken()
            return try await invokeCoachingSessionsPreview(weekStart: weekStart, token: token)
        } catch {
            throw Self.importFailure(from: error)
        }
    }

    /// Inserts the week's new sessions in Supabase, then pulls them. Nothing is
    /// written locally until that pull succeeds.
    func importCoachingSessions(weekStart: Date, in context: ModelContext) async throws -> Int {
        try await prepareCoachingImport()

        isBusy = true
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer {
            context.autosaveEnabled = autosave
            isBusy = false
        }

        let added: Int
        do {
            let token = try await validAccessToken()
            added = try await invokeImportCoachingSessions(weekStart: weekStart, token: token)
        } catch {
            throw Self.importFailure(from: error)
        }

        do {
            try await performSync(in: context)
        } catch {
            throw FinanceCloudError.importNotDownloaded
        }
        return added
    }

    /// Soft-deletes the live week on the server, then downloads that result.
    /// Local rows stay as they are until the download.
    func resetFinanceWeek(in context: ModelContext) async throws {
        try await runFinanceWeekChange(in: context, failure: .resetNeedsConnection) { token in
            try await invokeResetFinanceWeek(token: token)
        }
    }

    /// Rebuilds the week from predefined transactions. `unscheduledDay` is used
    /// only for a template that has no day of its own.
    func reinitializeFinanceWeek(unscheduledDay: String, in context: ModelContext) async throws {
        try await runFinanceWeekChange(in: context, failure: .initializeNeedsConnection) { token in
            try await invokeReinitializeFinanceWeek(unscheduledDay: unscheduledDay, token: token)
        }
    }

    private func runFinanceWeekChange(
        in context: ModelContext,
        failure: FinanceCloudError,
        rpc: (String) async throws -> Void
    ) async throws {
        try await prepareOnlineFinanceChange(failure: failure)

        isBusy = true
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer {
            context.autosaveEnabled = autosave
            isBusy = false
        }

        do {
            let token = try await validAccessToken()
            try await pushPendingChanges(token: token, context: context)
            try await rpc(token)
        } catch {
            throw failure
        }

        do {
            try await performSync(in: context)
        } catch {
            throw FinanceCloudError.weekChangeNotDownloaded
        }
    }

    private func prepareOnlineFinanceChange(failure: FinanceCloudError) async throws {
        let online = await Self.networkIsOnline()
        guard shouldUpdateFinanceWeekOnline(isSignedIn: isSignedIn, isOnline: online) else {
            throw failure
        }
        let deadline = Date().addingTimeInterval(60)
        while isBusy {
            if Date() >= deadline { throw failure }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func prepareCoachingImport() async throws {
        let online = await Self.networkIsOnline()
        guard shouldImportSessionsOnline(isSignedIn: isSignedIn, isOnline: online) else {
            throw FinanceCloudError.importNeedsConnection
        }
        let deadline = Date().addingTimeInterval(60)
        while isBusy {
            if Date() >= deadline { throw FinanceCloudError.importNeedsConnection }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private static func importFailure(from error: Error) -> Error {
        if let cloud = error as? FinanceCloudError {
            if case .notSignedIn = cloud { return FinanceCloudError.importNeedsConnection }
            if case .importNeedsConnection = cloud { return cloud }
            if case .importNotDownloaded = cloud { return cloud }
            if case .requestFailed = cloud { return cloud }
            if case .invalidResponse = cloud { return cloud }
            if case .workspaceUnavailable = cloud { return cloud }
            return FinanceCloudError.importNeedsConnection
        }
        return FinanceCloudError.importNeedsConnection
    }

    private func performSync(in context: ModelContext) async throws {
        NetIncomeManager.shared.flushPendingSave()
        let token = try await validAccessToken()
        try await verifyWorkspaceAccess(token: token)
        _ = try await syncCashFlow(token: token, context: context)
        _ = try await syncPredefined(token: token, context: context)
        _ = try await syncQuickAdd(token: token, context: context)
        let transactions = try await syncTransactions(token: token, context: context)
        _ = try await syncNetIncome(
            token: token,
            context: context,
            transactionDelta: transactions.balanceDelta
        )
    }

    private func pushTransactionIfNeeded(_ transaction: Transaction, context: ModelContext) async throws {
        guard transaction.needsCloudUpload else { return }
        let token = try await validAccessToken()
        let stamp = transaction.updatedAt
        let savedAt = try await upsert(
            table: "finance_transactions",
            body: transactionBody(transaction),
            token: token
        )
        guard transaction.updatedAt == stamp else { throw FinanceCloudError.needsConnection }
        transaction.updatedAt = savedAt
        transaction.lastSyncedAt = savedAt
        try context.save()
    }

    private func invokeCompleteFinanceTransaction(
        id: UUID,
        addToCashFlow: Bool,
        additionalCost: Double,
        splitNames: [String]?,
        token: String
    ) async throws {
        let call = completeFinanceTransactionCall(
            transactionID: id,
            addToCashFlow: addToCashFlow,
            additionalCost: additionalCost,
            splitNames: splitNames
        )
        let url = Self.endpoint(path: call.path, query: [])
        let payload = try JSONSerialization.data(withJSONObject: completeFinanceTransactionBody(call))
        let data = try await send(url: url, method: call.httpMethod, body: payload, token: token)
        guard (try? JSONDecoder().decode(Int.self, from: data)) != nil else {
            throw FinanceCloudError.invalidResponse
        }
    }

    private func invokeResetFinanceWeek(token: String) async throws {
        let call = resetFinanceWeekCall()
        let url = Self.endpoint(path: call.path, query: [])
        let payload = try JSONSerialization.data(withJSONObject: resetFinanceWeekBody())
        let data = try await send(url: url, method: call.httpMethod, body: payload, token: token)
        guard (try? JSONDecoder().decode(Int.self, from: data)) != nil else {
            throw FinanceCloudError.invalidResponse
        }
    }

    private func invokeReinitializeFinanceWeek(unscheduledDay: String, token: String) async throws {
        let call = reinitializeFinanceWeekCall(unscheduledDay: unscheduledDay)
        let url = Self.endpoint(path: call.path, query: [])
        let payload = try JSONSerialization.data(withJSONObject: reinitializeFinanceWeekBody(call))
        let data = try await send(url: url, method: call.httpMethod, body: payload, token: token)
        guard (try? JSONDecoder().decode(Int.self, from: data)) != nil else {
            throw FinanceCloudError.invalidResponse
        }
    }

    private func invokeCoachingSessionsPreview(weekStart: Date, token: String) async throws -> [CoachingSessionPreview] {
        let call = coachingSessionsPreviewCall(weekStart: weekStart)
        let url = Self.endpoint(path: call.path, query: [])
        let payload = try JSONSerialization.data(withJSONObject: coachingSessionsPreviewBody(call))
        let data = try await send(url: url, method: call.httpMethod, body: payload, token: token)
        do {
            return try makeDecoder().decode([CoachingSessionPreview].self, from: data)
        } catch {
            throw FinanceCloudError.invalidResponse
        }
    }

    private func invokeImportCoachingSessions(weekStart: Date, token: String) async throws -> Int {
        let call = importCoachingSessionsCall(weekStart: weekStart, sessionIDs: nil)
        let url = Self.endpoint(path: call.path, query: [])
        let payload = try JSONSerialization.data(withJSONObject: importCoachingSessionsBody(call))
        let data = try await send(url: url, method: call.httpMethod, body: payload, token: token)
        guard let added = try? JSONDecoder().decode(Int.self, from: data) else {
            throw FinanceCloudError.invalidResponse
        }
        return added
    }

    private func transactionBody(_ item: Transaction) -> [String: Any] {
        transactionUploadBody(
            id: item.id,
            workspaceID: FinanceCloudConfiguration.workspaceID,
            description: item.desc,
            amount: item.amount,
            dayOfWeek: item.dayOfWeek,
            isCompleted: item.isCompleted,
            isIncome: item.isIncome,
            updatedAt: item.updatedAt,
            deletedAt: item.deletedAt,
            coachingSessionID: item.coachingSessionID,
            coachingWeekStart: item.coachingWeekStart
        )
    }

    private static func networkIsOnline() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "MyFinanceTracker.complete.connectivity")
            var resumed = false
            monitor.pathUpdateHandler = { path in
                guard !resumed else { return }
                resumed = true
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: queue)
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
            select: "id,description,amount,day_of_week,is_completed,is_income,coaching_session_id,coaching_week_start,updated_at,deleted_at",
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
                    item.coachingSessionID = row.coachingSessionID
                    item.coachingWeekStart = row.coachingWeekStart
                    item.deletedAt = row.deletedAt
                    item.updatedAt = row.updatedAt
                    item.lastSyncedAt = row.updatedAt
                    counts.downloaded += 1
                case .uploadLocal:
                    keepCoachingLink(on: item, from: row)
                    pending.append(item)
                case .leave:
                    keepCoachingLink(on: item, from: row)
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
                    lastSyncedAt: row.updatedAt,
                    coachingSessionID: row.coachingSessionID,
                    coachingWeekStart: row.coachingWeekStart
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
        counts.balanceDelta = balanceDelta
        try context.save()
        counts.uploaded += try await upload(pending, table: "finance_transactions", token: token, context: context) { item in
            transactionBody(item)
        }
        return counts
    }

    /// Fills a missing local link from the server. Never writes null over a value
    /// this phone already has, and never uploads null for these columns.
    private func keepCoachingLink(on item: Transaction, from row: TransactionCloudRow) {
        if item.coachingSessionID == nil {
            item.coachingSessionID = row.coachingSessionID
        }
        if item.coachingWeekStart == nil {
            item.coachingWeekStart = row.coachingWeekStart
        }
    }

    private func syncNetIncome(
        token: String,
        context: ModelContext,
        transactionDelta: Double
    ) async throws -> SyncCounts {
        let remote = try await fetchAll(
            table: "finance_net_income",
            select: "id,value,updated_at,deleted_at",
            token: token,
            as: NetIncomeCloudRow.self
        )
        let local = try context.fetch(FetchDescriptor<NetIncomeEntity>())
        let beforePull = Dictionary(
            local.map { ($0.id, (value: $0.value, updatedAt: $0.updatedAt, lastSyncedAt: $0.lastSyncedAt)) },
            uniquingKeysWith: { first, _ in first }
        )
        let remoteByID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var byID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let remoteIDs = Set(remote.map(\.id))
        var counts = SyncCounts()
        var pending: [NetIncomeEntity] = []

        for row in remote {
            if let item = byID[row.id] {
                switch cloudMergeAction(localUpdatedAt: item.updatedAt, lastSyncedAt: item.lastSyncedAt, remoteUpdatedAt: row.updatedAt) {
                case .applyRemote:
                    item.value = row.value.value
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
                let item = NetIncomeEntity(
                    id: row.id,
                    value: row.value.value,
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
        let canonical = byID.values.filter { $0.deletedAt == nil }.max { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        let prior = canonical.flatMap { beforePull[$0.id] }
        let server = canonical.flatMap { remoteByID[$0.id] }
        let serverIsLive = server?.deletedAt == nil
        let action = netIncomePullAction(
            localValue: prior?.value ?? NetIncomeManager.shared.netIncome,
            localUpdatedAt: prior?.updatedAt ?? .distantPast,
            localLastSyncedAt: prior?.lastSyncedAt,
            serverValue: serverIsLive ? server?.value.value : nil,
            serverUpdatedAt: serverIsLive ? server?.updatedAt : nil,
            transactionDelta: transactionDelta
        )
        switch action {
        case .adoptServer(let value):
            if let canonical {
                canonical.value = value
                pending.removeAll { $0.id == canonical.id }
            }
            NetIncomeManager.shared.adoptStoredValue()
        case .adjustLocal(let value, let upload):
            if let canonical {
                if canonical.value != value {
                    canonical.value = value
                    canonical.markLocalEdit()
                }
                if upload, !pending.contains(where: { $0.id == canonical.id }) {
                    pending.append(canonical)
                }
                if NetIncomeManager.shared.netIncome != canonical.value {
                    NetIncomeManager.shared.adoptStoredValue()
                }
            } else if value != NetIncomeManager.shared.netIncome {
                NetIncomeManager.shared.applyRemoteTransactionDelta(value - NetIncomeManager.shared.netIncome)
            }
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

    /// Uploads rows edited on this phone. Does not download or change other local rows.
    private func pushPendingChanges(token: String, context: ModelContext) async throws {
        NetIncomeManager.shared.flushPendingSave()
        let workspace = FinanceCloudConfiguration.workspaceID.uuidString.lowercased()

        let cashFlow = try context.fetch(FetchDescriptor<CashFlowItem>()).filter { $0.needsCloudUpload }
        _ = try await upload(cashFlow, table: "finance_cash_flow_items", token: token, context: context) { item in
            [
                "id": item.id.uuidString.lowercased(),
                "workspace_id": workspace,
                "name": item.name ?? NSNull(),
                "amount": item.amount,
                "is_owed_to_me": item.isOwedToMe,
                "is_settled": item.isSettled,
                "updated_at": SupabaseTimestamp.format(item.updatedAt),
                "deleted_at": item.deletedAt.map(SupabaseTimestamp.format) ?? NSNull()
            ]
        }

        let predefined = try context.fetch(FetchDescriptor<PredefinedTransaction>()).filter { $0.needsCloudUpload }
        _ = try await upload(predefined, table: "finance_predefined_transactions", token: token, context: context) { item in
            [
                "id": item.id.uuidString.lowercased(),
                "workspace_id": workspace,
                "description": item.desc ?? NSNull(),
                "amount": item.amount,
                "day_of_week": item.dayOfWeek ?? NSNull(),
                "is_income": item.isIncome,
                "updated_at": SupabaseTimestamp.format(item.updatedAt),
                "deleted_at": item.deletedAt.map(SupabaseTimestamp.format) ?? NSNull()
            ]
        }

        let quickAdd = try context.fetch(FetchDescriptor<QuickAddTransaction>()).filter { $0.needsCloudUpload }
        _ = try await upload(quickAdd, table: "finance_quick_add_transactions", token: token, context: context) { item in
            [
                "id": item.id.uuidString.lowercased(),
                "workspace_id": workspace,
                "description": item.desc ?? NSNull(),
                "amount": item.amount,
                "is_income": item.isIncome,
                "updated_at": SupabaseTimestamp.format(item.updatedAt),
                "deleted_at": item.deletedAt.map(SupabaseTimestamp.format) ?? NSNull()
            ]
        }

        let transactions = try context.fetch(FetchDescriptor<Transaction>()).filter { $0.needsCloudUpload }
        _ = try await upload(transactions, table: "finance_transactions", token: token, context: context) { item in
            transactionBody(item)
        }

        let income = try context.fetch(FetchDescriptor<NetIncomeEntity>()).filter { $0.needsCloudUpload }
        _ = try await upload(income, table: "finance_net_income", token: token, context: context) { item in
            [
                "id": item.id.uuidString.lowercased(),
                "workspace_id": workspace,
                "value": item.value,
                "updated_at": SupabaseTimestamp.format(item.updatedAt),
                "deleted_at": item.deletedAt.map(SupabaseTimestamp.format) ?? NSNull()
            ]
        }
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
        if !query.isEmpty {
            components.queryItems = query
        }
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
    var balanceDelta = 0.0
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
    let coachingSessionID: UUID?
    let coachingWeekStart: Date?
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, description, amount
        case dayOfWeek = "day_of_week"
        case isCompleted = "is_completed"
        case isIncome = "is_income"
        case coachingSessionID = "coaching_session_id"
        case coachingWeekStart = "coaching_week_start"
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
    case needsConnection
    case completionNotDownloaded
    case importNeedsConnection
    case importNotDownloaded
    case resetNeedsConnection
    case initializeNeedsConnection
    case weekChangeNotDownloaded

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
        case .needsConnection:
            return "Ticking a transaction needs an internet connection."
        case .completionNotDownloaded:
            return "The transaction was ticked online, but this phone couldn't download it. Pull to refresh."
        case .importNeedsConnection:
            return "Importing sessions needs an internet connection."
        case .importNotDownloaded:
            return "The import finished online, but this phone couldn't download it. Pull to refresh."
        case .resetNeedsConnection:
            return "Resetting the week needs an internet connection."
        case .initializeNeedsConnection:
            return "Initializing the week needs an internet connection."
        case .weekChangeNotDownloaded:
            return "The week was updated online, but this phone couldn't download it. Pull to refresh."
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
