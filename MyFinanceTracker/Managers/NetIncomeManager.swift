import Foundation
import SwiftData

@MainActor
final class NetIncomeManager: ObservableObject {
    static let shared = NetIncomeManager()

    @Published var netIncome: Double = 0.0 {
        didSet { scheduleSave() }
    }

    private var saveTask: Task<Void, Never>?
    private var suppressSave = false

    private var context: ModelContext { AppContainer.shared.mainContext }

    private init() {
        loadNetIncome()
    }

    func adjustNetIncome(by amount: Double, isIncome: Bool, isDeletion: Bool = false) {
        let adjustment = isDeletion ? -amount : amount
        netIncome += isIncome ? adjustment : -adjustment
    }

    func resetNetIncome() {
        netIncome = 0.0
        flushPendingSave()
    }

    /// Writes the debounced balance immediately so a sync sees the latest value.
    func flushPendingSave() {
        saveTask?.cancel()
        saveTask = nil
        saveNetIncome()
    }

    /// Includes a remote transaction that this phone had not already counted.
    /// Completing a transaction does not come through here.
    func applyRemoteTransactionDelta(_ delta: Double) {
        guard delta != 0 else { return }
        suppressSave = true
        netIncome += delta
        suppressSave = false
        flushPendingSave()
    }

    /// Reloads the published balance after a newer cloud row was applied.
    func adoptStoredValue() {
        saveTask?.cancel()
        saveTask = nil
        suppressSave = true
        netIncome = (try? canonicalEntity())?.value ?? 0
        suppressSave = false
    }

    // MARK: - Persistence

    private func scheduleSave() {
        guard !suppressSave else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.saveNetIncome()
        }
    }

    private func saveNetIncome() {
        do {
            if let entity = try canonicalEntity() {
                guard entity.value != netIncome else { return }
                entity.value = netIncome
                entity.markLocalEdit()
            } else {
                context.insert(NetIncomeEntity(value: netIncome))
            }
            try context.save()
        } catch {
            print("Failed to save net income: \(error.localizedDescription)")
        }
    }

    private func loadNetIncome() {
        do {
            if let entity = try canonicalEntity() {
                suppressSave = true
                netIncome = entity.value
                suppressSave = false
            } else {
                context.insert(NetIncomeEntity(value: 0.0))
                try context.save()
                suppressSave = true
                netIncome = 0
                suppressSave = false
            }
        } catch {
            print("Failed to load net income: \(error.localizedDescription)")
        }
    }

    /// The live balance is the newest row that has not been soft-deleted.
    private func canonicalEntity() throws -> NetIncomeEntity? {
        try context.fetch(FetchDescriptor<NetIncomeEntity>())
            .filter { $0.deletedAt == nil }
            .max { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }
}
