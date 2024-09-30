import Foundation
import Combine
import CoreData

class NetIncomeManager: ObservableObject {
    static let shared = NetIncomeManager()

    @Published var netIncome: Double = 0.0
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadNetIncome()

        $netIncome
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveNetIncome()
            }
            .store(in: &cancellables)
    }

    func adjustNetIncome(by amount: Double, isIncome: Bool, isDeletion: Bool = false) {
        let adjustment = isDeletion ? -amount : amount
        netIncome += isIncome ? adjustment : -adjustment
    }

    private func saveNetIncome() {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<NetIncomeEntity> = NetIncomeEntity.fetchRequest()
        do {
            let results = try context.fetch(fetchRequest)
            if let netIncomeEntity = results.first {
                netIncomeEntity.value = netIncome
            } else {
                let newEntity = NetIncomeEntity(context: context)
                newEntity.value = netIncome
            }
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
            if let netIncomeEntity = results.first {
                netIncome = netIncomeEntity.value
            } else {
                netIncome = 0.0
                let newEntity = NetIncomeEntity(context: context)
                newEntity.value = 0.0
                try context.save()
            }
        } catch {
            print("Failed to load net income: \(error.localizedDescription)")
        }
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
}
