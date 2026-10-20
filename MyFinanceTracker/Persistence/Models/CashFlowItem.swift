import Foundation
import SwiftData

@Model
final class CashFlowItem {
    var id: UUID
    var name: String?
    var amount: Double
    var isOwedToMe: Bool
    var isSettled: Bool
    var updatedAt: Date = Date.now
    var deletedAt: Date? = nil
    var lastSyncedAt: Date? = nil

    init(
        id: UUID = UUID(),
        name: String? = nil,
        amount: Double = 0,
        isOwedToMe: Bool = false,
        isSettled: Bool = false,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.isOwedToMe = isOwedToMe
        self.isSettled = isSettled
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.lastSyncedAt = lastSyncedAt
    }
}

extension CashFlowItem: FinanceSyncRecord {}
