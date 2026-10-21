import Foundation

protocol FinanceSyncRecord: AnyObject {
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
    var lastSyncedAt: Date? { get set }
}

extension FinanceSyncRecord {
    func markLocalEdit() {
        updatedAt = .now
    }

    func markDeleted() {
        if deletedAt == nil {
            deletedAt = .now
        }
        updatedAt = .now
    }

    var needsCloudUpload: Bool {
        guard let lastSyncedAt else { return true }
        return updatedAt > lastSyncedAt
    }
}

enum CloudMergeAction: Equatable {
    case applyRemote
    case uploadLocal
    case leave
}

/// Last-write-wins on `updatedAt`. A missing remote row is uploaded again so a
/// short or failed download cannot drop the phone's copy.
func cloudMergeAction(
    localUpdatedAt: Date,
    lastSyncedAt: Date?,
    remoteUpdatedAt: Date?
) -> CloudMergeAction {
    guard let remoteUpdatedAt else { return .uploadLocal }
    if remoteUpdatedAt > localUpdatedAt { return .applyRemote }
    if lastSyncedAt == nil || localUpdatedAt > lastSyncedAt! { return .uploadLocal }
    return .leave
}

func transactionBalanceContribution(amount: Double, isIncome: Bool, isDeleted: Bool) -> Double {
    guard !isDeleted else { return 0 }
    return isIncome ? amount : -amount
}

func transactionBalanceDelta(
    oldAmount: Double,
    oldIsIncome: Bool,
    oldIsDeleted: Bool,
    newAmount: Double,
    newIsIncome: Bool,
    newIsDeleted: Bool
) -> Double {
    transactionBalanceContribution(amount: newAmount, isIncome: newIsIncome, isDeleted: newIsDeleted)
        - transactionBalanceContribution(amount: oldAmount, isIncome: oldIsIncome, isDeleted: oldIsDeleted)
}

enum NetIncomePullAction: Equatable {
    /// The server balance is newer. Keep it and do not upload a local adjustment.
    case adoptServer(Double)
    /// The server balance did not replace the phone's row.
    case adjustLocal(value: Double, upload: Bool)
}

/// Transaction downloads must not be added on top of a server balance and then
/// uploaded back over it. A completion has a zero delta, so the balance stays.
func netIncomePullAction(
    localValue: Double,
    localUpdatedAt: Date,
    localLastSyncedAt: Date?,
    serverValue: Double?,
    serverUpdatedAt: Date?,
    transactionDelta: Double
) -> NetIncomePullAction {
    switch cloudMergeAction(
        localUpdatedAt: localUpdatedAt,
        lastSyncedAt: localLastSyncedAt,
        remoteUpdatedAt: serverUpdatedAt
    ) {
    case .applyRemote:
        return .adoptServer(serverValue ?? localValue)
    case .leave:
        if transactionDelta == 0 {
            return .adjustLocal(value: localValue, upload: false)
        }
        return .adjustLocal(value: localValue + transactionDelta, upload: true)
    case .uploadLocal:
        return .adjustLocal(value: localValue + transactionDelta, upload: true)
    }
}

func shouldUpdateFinanceWeekOnline(isSignedIn: Bool, isOnline: Bool) -> Bool {
    isSignedIn && isOnline
}

struct ResetFinanceWeekCall: Equatable {
    var httpMethod: String
    var path: String
}

func resetFinanceWeekCall() -> ResetFinanceWeekCall {
    ResetFinanceWeekCall(httpMethod: "POST", path: "/rest/v1/rpc/reset_finance_week")
}

func resetFinanceWeekBody() -> [String: Any] {
    [:]
}

struct ReinitializeFinanceWeekCall: Equatable {
    var httpMethod: String
    var path: String
    var unscheduledDay: String
}

func reinitializeFinanceWeekCall(unscheduledDay: String) -> ReinitializeFinanceWeekCall {
    ReinitializeFinanceWeekCall(
        httpMethod: "POST",
        path: "/rest/v1/rpc/reinitialize_finance_week",
        unscheduledDay: unscheduledDay
    )
}

func reinitializeFinanceWeekBody(_ call: ReinitializeFinanceWeekCall) -> [String: Any] {
    ["p_unscheduled_day": call.unscheduledDay]
}

struct CompleteFinanceTransactionCall: Equatable {
    var httpMethod: String
    var path: String
    var transactionID: String
    var addToCashFlow: Bool
    var additionalCost: Double
    var splitNames: [String]?
}

/// Builds the PostgREST body for `public.complete_finance_transaction`.
/// Names are sent as entered; the database trims and drops blanks.
func completeFinanceTransactionCall(
    transactionID: UUID,
    addToCashFlow: Bool,
    additionalCost: Double,
    splitNames: [String]?
) -> CompleteFinanceTransactionCall {
    CompleteFinanceTransactionCall(
        httpMethod: "POST",
        path: "/rest/v1/rpc/complete_finance_transaction",
        transactionID: transactionID.uuidString.lowercased(),
        addToCashFlow: addToCashFlow,
        additionalCost: additionalCost,
        splitNames: splitNames
    )
}

func completeFinanceTransactionBody(_ call: CompleteFinanceTransactionCall) -> [String: Any] {
    [
        "p_transaction_id": call.transactionID,
        "p_add_to_cash_flow": call.addToCashFlow,
        "p_additional_cost": call.additionalCost,
        "p_split_names": call.splitNames.map { $0 as Any } ?? NSNull()
    ]
}

func shouldCompleteTransactionOnline(isSignedIn: Bool, isOnline: Bool) -> Bool {
    isSignedIn && isOnline
}

enum IncomeTickChoice: Equatable {
    case tick
    case addToCashFlow
    case cancel
}

/// Cancel leaves the row unticked and must not call `complete_finance_transaction`.
/// Tick and Add to who owes me both complete it.
func shouldCompleteTransaction(for choice: IncomeTickChoice) -> Bool {
    switch choice {
    case .tick, .addToCashFlow:
        return true
    case .cancel:
        return false
    }
}

struct PredefinedWeekRow: Equatable {
    var amount: Double
    var isIncome: Bool
    var dayOfWeek: String?
    var isDeleted: Bool = false
}

func initializeWeekConfirmationMessage(total: Double) -> String {
    "This replaces this week’s transactions with your predefined ones. The balance becomes \(total.formattedAsCurrency())."
}

/// Signed total Initialize Week writes after replacing this week's transactions.
/// Income is positive and expense is negative. "Every day" counts as seven rows.
/// A missing day counts once, on `unscheduledDay`, matching `reinitialize_finance_week`.
func predefinedWeekBalance(_ rows: [PredefinedWeekRow], unscheduledDay: String) -> Double {
    rows.reduce(0) { sum, row in
        guard !row.isDeleted else { return sum }
        let day = row.dayOfWeek ?? unscheduledDay
        let copies = day == PredefinedTransaction.everyDaySchedule ? 7.0 : 1.0
        let signed = row.isIncome ? row.amount : -row.amount
        return sum + signed * copies
    }
}

func shouldImportSessionsOnline(isSignedIn: Bool, isOnline: Bool) -> Bool {
    isSignedIn && isOnline
}

/// Something the phone cannot finish by retrying on its own.
enum FinanceSyncNotice: Equatable {
    case needsSignIn
    case accountBlocked
    case uploadsNotSending
}

enum FinanceSyncPromptKind: Equatable {
    case signIn
    case accountBlocked
    case uploadsNotSending
}

/// Offline blips stay quiet. A prompt appears on the third failure that is not a network drop.
let financeUploadFailurePromptThreshold = 3

func financeSyncPrompt(isSignedIn: Bool, notice: FinanceSyncNotice?) -> FinanceSyncPromptKind? {
    if !isSignedIn || notice == .needsSignIn { return .signIn }
    switch notice {
    case .accountBlocked:
        return .accountBlocked
    case .uploadsNotSending:
        return .uploadsNotSending
    case .needsSignIn, nil:
        return nil
    }
}

func isTransientFinanceSyncError(_ error: Error) -> Bool {
    guard let urlError = error as? URLError else { return false }
    switch urlError.code {
    case .notConnectedToInternet, .networkConnectionLost, .timedOut,
         .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
         .dataNotAllowed, .internationalRoamingOff, .cancelled:
        return true
    default:
        return false
    }
}

/// Updates the attention flag after one sync attempt. A nil error means that attempt succeeded.
func nextFinanceSyncNotice(
    isSignedIn: Bool,
    error: Error?,
    consecutiveFailures: Int,
    current: FinanceSyncNotice?
) -> (notice: FinanceSyncNotice?, consecutiveFailures: Int) {
    if !isSignedIn {
        return (nil, 0)
    }
    guard let error else {
        return (nil, 0)
    }
    if let cloud = error as? FinanceCloudError, case .notSignedIn = cloud {
        return (.needsSignIn, 0)
    }
    if let cloud = error as? FinanceCloudError, case .workspaceUnavailable = cloud {
        return (.accountBlocked, consecutiveFailures)
    }
    if isTransientFinanceSyncError(error) {
        return (current, consecutiveFailures)
    }
    if current == .needsSignIn || current == .accountBlocked {
        return (current, consecutiveFailures)
    }
    let failures = consecutiveFailures + 1
    if failures >= financeUploadFailurePromptThreshold {
        return (.uploadsNotSending, failures)
    }
    return (nil, failures)
}

struct CoachingSessionPreview: Decodable, Identifiable, Equatable {
    let sessionID: UUID
    let weekStart: Date
    let dayOfWeek: String
    let sessionName: String
    let sessionFee: Double
    let startTime: Date
    let alreadyImported: Bool

    var id: UUID { sessionID }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case weekStart = "week_start"
        case dayOfWeek = "day_of_week"
        case sessionName = "session_name"
        case sessionFee = "session_fee"
        case startTime = "start_time"
        case alreadyImported = "already_imported"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(UUID.self, forKey: .sessionID)
        weekStart = try container.decode(Date.self, forKey: .weekStart)
        dayOfWeek = try container.decodeIfPresent(String.self, forKey: .dayOfWeek) ?? ""
        let name = try container.decodeIfPresent(String.self, forKey: .sessionName)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        sessionName = name.isEmpty ? "Coaching" : name
        sessionFee = try Self.decodeFee(container)
        startTime = try container.decode(Date.self, forKey: .startTime)
        alreadyImported = try container.decodeIfPresent(Bool.self, forKey: .alreadyImported) ?? false
    }

    private static func decodeFee(_ container: KeyedDecodingContainer<CodingKeys>) throws -> Double {
        if let number = try? container.decode(Double.self, forKey: .sessionFee) {
            return number
        }
        if let text = try? container.decode(String.self, forKey: .sessionFee), let number = Double(text) {
            return number
        }
        if try container.decodeNil(forKey: .sessionFee) {
            return 0
        }
        throw DecodingError.dataCorruptedError(
            forKey: .sessionFee,
            in: container,
            debugDescription: "Expected a session fee"
        )
    }
}

/// Sessions the import function will insert: not already imported, fee above zero.
func importableCoachingSessions(_ sessions: [CoachingSessionPreview]) -> [CoachingSessionPreview] {
    sessions.filter { !$0.alreadyImported && $0.sessionFee > 0 }
}

func importSessionsSuccessMessage(added: Int) -> String {
    if added == 0 {
        return "No new sessions were added."
    }
    if added == 1 {
        return "Added 1 income transaction."
    }
    return "Added \(added) income transactions."
}

struct CoachingSessionsPreviewCall: Equatable {
    var httpMethod: String
    var path: String
    var weekStart: String
}

func coachingSessionsPreviewCall(weekStart: Date) -> CoachingSessionsPreviewCall {
    CoachingSessionsPreviewCall(
        httpMethod: "POST",
        path: "/rest/v1/rpc/coaching_sessions_for_finance",
        weekStart: PerthWeek.dateOnlyString(from: weekStart)
    )
}

func coachingSessionsPreviewBody(_ call: CoachingSessionsPreviewCall) -> [String: Any] {
    ["p_week_start": call.weekStart]
}

struct ImportCoachingSessionsCall: Equatable {
    var httpMethod: String
    var path: String
    var weekStart: String
    var sessionIDs: [String]?
}

/// `sessionIDs == nil` asks the function to import the whole week.
func importCoachingSessionsCall(weekStart: Date, sessionIDs: [UUID]?) -> ImportCoachingSessionsCall {
    ImportCoachingSessionsCall(
        httpMethod: "POST",
        path: "/rest/v1/rpc/import_coaching_sessions_to_finance",
        weekStart: PerthWeek.dateOnlyString(from: weekStart),
        sessionIDs: sessionIDs?.map { $0.uuidString.lowercased() }
    )
}

func importCoachingSessionsBody(_ call: ImportCoachingSessionsCall) -> [String: Any] {
    [
        "p_week_start": call.weekStart,
        "p_session_ids": call.sessionIDs.map { $0 as Any } ?? NSNull()
    ]
}

/// Upsert body for `finance_transactions`. Nil coaching link fields are left
/// out so merge-duplicates cannot clear a value this phone has not loaded.
func transactionUploadBody(
    id: UUID,
    workspaceID: UUID,
    description: String?,
    amount: Double,
    dayOfWeek: String?,
    isCompleted: Bool,
    isIncome: Bool,
    updatedAt: Date,
    deletedAt: Date?,
    coachingSessionID: UUID?,
    coachingWeekStart: Date?
) -> [String: Any] {
    var body: [String: Any] = [
        "id": id.uuidString.lowercased(),
        "workspace_id": workspaceID.uuidString.lowercased(),
        "description": description ?? NSNull(),
        "amount": amount,
        "day_of_week": dayOfWeek ?? NSNull(),
        "is_completed": isCompleted,
        "is_income": isIncome,
        "updated_at": SupabaseTimestamp.format(updatedAt),
        "deleted_at": deletedAt.map(SupabaseTimestamp.format) ?? NSNull()
    ]
    if let coachingSessionID {
        body["coaching_session_id"] = coachingSessionID.uuidString.lowercased()
    }
    if let coachingWeekStart {
        body["coaching_week_start"] = SupabaseTimestamp.formatDateOnly(coachingWeekStart)
    }
    return body
}

enum SupabaseTimestamp {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let wholeSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()

    static func format(_ date: Date) -> String {
        fractional.string(from: date)
    }

    /// Calendar date stored for `coaching_week_start`. Parsed date-only values
    /// are UTC midnight, so formatting them here returns the same `yyyy-MM-dd`.
    static func formatDateOnly(_ date: Date) -> String {
        dateOnly.string(from: date)
    }

    static func parse(_ value: String) -> Date? {
        if let date = fractional.date(from: value) { return date }
        if let date = wholeSeconds.date(from: value) { return date }
        if value.count == 10, let date = dateOnly.date(from: value) { return date }
        let normalized = trimmingFraction(value)
        guard normalized != value else { return nil }
        return fractional.date(from: normalized) ?? wholeSeconds.date(from: normalized)
    }

    /// ISO8601DateFormatter accepts milliseconds. Supabase often returns microseconds.
    private static func trimmingFraction(_ value: String) -> String {
        guard let dot = value.firstIndex(of: ".") else { return value }
        let digitsStart = value.index(after: dot)
        var digitsEnd = digitsStart
        while digitsEnd < value.endIndex, value[digitsEnd].isNumber {
            digitsEnd = value.index(after: digitsEnd)
        }
        let digits = value[digitsStart..<digitsEnd]
        guard digits.count > 3 else { return value }
        return String(value[..<digitsStart]) + digits.prefix(3) + value[digitsEnd...]
    }
}
