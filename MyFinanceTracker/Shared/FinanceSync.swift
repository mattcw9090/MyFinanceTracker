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

    static func format(_ date: Date) -> String {
        fractional.string(from: date)
    }

    static func parse(_ value: String) -> Date? {
        if let date = fractional.date(from: value) { return date }
        if let date = wholeSeconds.date(from: value) { return date }
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
