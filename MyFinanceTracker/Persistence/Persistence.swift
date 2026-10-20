import Foundation
import SwiftData

// MARK: - Versioned schema
// V1 is the store already on the phone. Its nested models keep the original
// fields so lightweight migration can add the sync columns in V2.

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
            CashFlowItem.self,
            NetIncomeEntity.self,
            PredefinedTransaction.self,
            QuickAddTransaction.self,
            Transaction.self
        ]
    }
}

/// Lists schema versions in order. SwiftData lightweight-migrates V1 to V2
/// by adding the sync fields. New fields have defaults, so existing rows stay.
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self, AppSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AppSchemaV1.self,
        toVersion: AppSchemaV2.self
    )
}

// MARK: - Shared container

enum AppContainer {
    static let shared: ModelContainer = {
        do {
            let schema = Schema(versionedSchema: AppSchemaV2.self)
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
