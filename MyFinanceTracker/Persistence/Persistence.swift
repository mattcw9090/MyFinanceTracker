import Foundation
import SwiftData

// MARK: - Versioned schema
// V1 is the original store. V2 adds the sync columns. V3 adds optional
// coaching-session link fields and is what's on the phone today. V4 drops
// QuickAddTransaction. Each older version keeps that model so the migration
// can delete its table without rewriting the other rows.

enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CashFlowItem.self,
            NetIncomeEntity.self,
            PredefinedTransaction.self,
            QuickAddTransaction.self,
            Transaction.self
        ]
    }
}

extension AppSchemaV1 {
    @Model
    final class CashFlowItem {
        var id: UUID
        var name: String?
        var amount: Double
        var isOwedToMe: Bool
        var isSettled: Bool

        init(
            id: UUID = UUID(),
            name: String? = nil,
            amount: Double = 0,
            isOwedToMe: Bool = false,
            isSettled: Bool = false
        ) {
            self.id = id
            self.name = name
            self.amount = amount
            self.isOwedToMe = isOwedToMe
            self.isSettled = isSettled
        }
    }

    @Model
    final class NetIncomeEntity {
        var value: Double

        init(value: Double = 0.0) {
            self.value = value
        }
    }

    @Model
    final class PredefinedTransaction {
        var id: UUID
        var desc: String?
        var amount: Double
        var dayOfWeek: String?
        var isIncome: Bool

        init(
            id: UUID = UUID(),
            desc: String? = nil,
            amount: Double = 0,
            dayOfWeek: String? = nil,
            isIncome: Bool = false
        ) {
            self.id = id
            self.desc = desc
            self.amount = amount
            self.dayOfWeek = dayOfWeek
            self.isIncome = isIncome
        }
    }

    @Model
    final class QuickAddTransaction {
        var id: UUID
        var desc: String?
        var amount: Double
        var isIncome: Bool

        init(
            id: UUID = UUID(),
            desc: String? = nil,
            amount: Double = 0,
            isIncome: Bool = false
        ) {
            self.id = id
            self.desc = desc
            self.amount = amount
            self.isIncome = isIncome
        }
    }

    @Model
    final class Transaction {
        var id: UUID
        var desc: String?
        var amount: Double
        var dayOfWeek: String?
        var isCompleted: Bool
        var isIncome: Bool

        init(
            id: UUID = UUID(),
            desc: String? = nil,
            amount: Double = 0,
            dayOfWeek: String? = nil,
            isCompleted: Bool = false,
            isIncome: Bool = false
        ) {
            self.id = id
            self.desc = desc
            self.amount = amount
            self.dayOfWeek = dayOfWeek
            self.isCompleted = isCompleted
            self.isIncome = isIncome
        }
    }
}

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] {
        [
            AppSchemaV2.CashFlowItem.self,
            AppSchemaV2.NetIncomeEntity.self,
            AppSchemaV2.PredefinedTransaction.self,
            AppSchemaV2.QuickAddTransaction.self,
            AppSchemaV2.Transaction.self
        ]
    }
}

extension AppSchemaV2 {
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

    @Model
    final class PredefinedTransaction {
        var id: UUID
        var desc: String?
        var amount: Double
        var dayOfWeek: String?
        var isIncome: Bool
        var updatedAt: Date = Date.now
        var deletedAt: Date? = nil
        var lastSyncedAt: Date? = nil

        init(
            id: UUID = UUID(),
            desc: String? = nil,
            amount: Double = 0,
            dayOfWeek: String? = nil,
            isIncome: Bool = false,
            updatedAt: Date = .now,
            deletedAt: Date? = nil,
            lastSyncedAt: Date? = nil
        ) {
            self.id = id
            self.desc = desc
            self.amount = amount
            self.dayOfWeek = dayOfWeek
            self.isIncome = isIncome
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
            self.lastSyncedAt = lastSyncedAt
        }
    }

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

    @Model
    final class Transaction {
        var id: UUID
        var desc: String?
        var amount: Double
        var dayOfWeek: String?
        var isCompleted: Bool
        var isIncome: Bool
        var updatedAt: Date = Date.now
        var deletedAt: Date? = nil
        var lastSyncedAt: Date? = nil

        init(
            id: UUID = UUID(),
            desc: String? = nil,
            amount: Double = 0,
            dayOfWeek: String? = nil,
            isCompleted: Bool = false,
            isIncome: Bool = false,
            updatedAt: Date = .now,
            deletedAt: Date? = nil,
            lastSyncedAt: Date? = nil
        ) {
            self.id = id
            self.desc = desc
            self.amount = amount
            self.dayOfWeek = dayOfWeek
            self.isCompleted = isCompleted
            self.isIncome = isIncome
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
            self.lastSyncedAt = lastSyncedAt
        }
    }
}

enum AppSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 2, 0)

    static var models: [any PersistentModel.Type] {
        [
            CashFlowItem.self,
            NetIncomeEntity.self,
            PredefinedTransaction.self,
            AppSchemaV3.QuickAddTransaction.self,
            Transaction.self
        ]
    }
}

extension AppSchemaV3 {
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
}

enum AppSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 3, 0)

    static var models: [any PersistentModel.Type] {
        [
            CashFlowItem.self,
            NetIncomeEntity.self,
            PredefinedTransaction.self,
            Transaction.self
        ]
    }
}

/// Lists schema versions in order. Lightweight migration adds the sync fields
/// in V2, the optional coaching link fields in V3, and drops Quick Add in V4.
/// New fields have defaults, so existing rows of the remaining models stay.
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self, AppSchemaV2.self, AppSchemaV3.self, AppSchemaV4.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AppSchemaV1.self,
        toVersion: AppSchemaV2.self
    )

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: AppSchemaV2.self,
        toVersion: AppSchemaV3.self
    )

    static let migrateV3toV4 = MigrationStage.lightweight(
        fromVersion: AppSchemaV3.self,
        toVersion: AppSchemaV4.self
    )
}

// MARK: - Shared container

enum AppContainer {
    static let shared: ModelContainer = {
        do {
            let schema = Schema(versionedSchema: AppSchemaV4.self)
            let config = ModelConfiguration(schema: schema, groupContainer: .none)
            return try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
