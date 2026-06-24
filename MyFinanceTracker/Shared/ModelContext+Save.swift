import SwiftData

extension ModelContext {
    /// Saves the context if it has changes, logging failures instead of throwing.
    /// Use for non-critical saves where a print log is acceptable.
    func saveOrLog(_ label: StaticString = #function) {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            print("⚠️ Failed to save context (\(label)): \(error.localizedDescription)")
        }
    }
}
