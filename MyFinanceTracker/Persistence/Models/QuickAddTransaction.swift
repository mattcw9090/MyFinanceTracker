import Foundation
import SwiftData

@Model
final class QuickAddTransaction {
    var id: UUID
    var desc: String?
    var amount: Double
    var isIncome: Bool
    var updatedAt: Date = Date.now
    var deletedAt: Date? = nil
    var lastSyncedAt: Date? = nil

    init(
        id: UUID = UUID(),
        desc: String? = nil,
        amount: Double = 0,
        isIncome: Bool = false,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.desc = desc
        self.amount = amount
        self.isIncome = isIncome
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.lastSyncedAt = lastSyncedAt
    }
}

extension QuickAddTransaction: FinanceSyncRecord {}
