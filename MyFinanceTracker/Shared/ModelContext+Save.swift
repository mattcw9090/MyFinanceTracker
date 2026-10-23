import SwiftData

extension ModelContext {
    /// Saves the context if it has changes, logging failures instead of throwing.
    /// Use for non-critical saves where a print log is acceptable.
    @MainActor
    func saveOrLog(_ label: StaticString = #function) {
        guard hasChanges else { return }
        do {
            try save()
            FinanceCloud.shared.noteLocalEdit()
        } catch {
            print("⚠️ Failed to save context (\(label)): \(error.localizedDescription)")
        }
    }

    /// Saves a user insert, edit, or soft delete and schedules an upload.
    @MainActor
    func saveLocalChange() throws {
        try save()
        FinanceCloud.shared.noteLocalEdit()
    }
}
