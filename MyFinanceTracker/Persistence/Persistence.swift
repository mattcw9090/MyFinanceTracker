import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MyFinanceTracker")

        if let description = container.persistentStoreDescriptions.first {
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
            // Lightweight migration: Core Data infers a mapping model when the
            // schema changes additively (new attributes with default values,
            // newly-optional attributes, renames via renamingIdentifier).
            // For anything more complex, add a new model version in
            // MyFinanceTracker.xcdatamodeld (Editor → Add Model Version) so
            // Core Data has an explicit source-to-destination pair to map.
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // Fail loudly. We never silently destroy the user's store —
                // if migration is failing, the right fix is to add a model
                // version, not to discard their data.
                fatalError("Core Data load failed: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
