import Foundation
import SwiftData

// MARK: - Versioned schema (add a new VersionedSchema below for each future change)

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

/// Lists all schema versions in chronological order and the migration stages
/// connecting them. SwiftData performs lightweight migration between
/// consecutive versions automatically; add a `.custom(...)` stage when a
/// change requires data transformation.
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

// MARK: - Shared container

enum AppContainer {
    /// One container, shared by SwiftUI's `.modelContainer` modifier and by
    /// `NetIncomeManager`. Both must use the same store to see the same data.
    static let shared: ModelContainer = {
        do {
            let schema = Schema(versionedSchema: AppSchemaV1.self)
            let config = ModelConfiguration(schema: schema)
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
