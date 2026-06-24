import Foundation
import CoreData

@MainActor
final class NetIncomeManager: ObservableObject {
    static let shared = NetIncomeManager()

    @Published var netIncome: Double = 0.0 {
        didSet { scheduleSave() }
    }

    private var saveTask: Task<Void, Never>?

    private init() {
        loadNetIncome()
    }

    func adjustNetIncome(by amount: Double, isIncome: Bool, isDeletion: Bool = false) {
        let adjustment = isDeletion ? -amount : amount
        netIncome += isIncome ? adjustment : -adjustment
    }

    func resetNetIncome() {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NetIncomeEntity.fetchRequest()
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try context.execute(batchDeleteRequest)
            netIncome = 0.0
        } catch {
            print("Failed to reset net income: \(error.localizedDescription)")
        }
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.saveNetIncome()
        }
    }

    private func saveNetIncome() {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<NetIncomeEntity> = NetIncomeEntity.fetchRequest()
        do {
            let results = try context.fetch(fetchRequest)
            let entity = results.first ?? NetIncomeEntity(context: context)
            entity.value = netIncome
            try context.save()
        } catch {
            print("Failed to save net income: \(error.localizedDescription)")
        }
    }

    private func loadNetIncome() {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<NetIncomeEntity> = NetIncomeEntity.fetchRequest()
        do {
            let results = try context.fetch(fetchRequest)
            if let entity = results.first {
                netIncome = entity.value
            } else {
                let entity = NetIncomeEntity(context: context)
                entity.value = 0.0
                try context.save()
            }
        } catch {
            print("Failed to load net income: \(error.localizedDescription)")
        }
    }
}
