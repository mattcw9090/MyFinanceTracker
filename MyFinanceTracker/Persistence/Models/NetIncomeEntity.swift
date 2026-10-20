import Foundation
import SwiftData

@Model
final class NetIncomeEntity {
    var id: UUID = UUID()
    var value: Double
    var updatedAt: Date = Date.now
    var deletedAt: Date? = nil
    var lastSyncedAt: Date? = nil

    init(
        id: UUID = UUID(),
        value: Double = 0.0,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.value = value
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.lastSyncedAt = lastSyncedAt
    }
}

extension NetIncomeEntity: FinanceSyncRecord {}
