import Foundation
import SwiftData

@MainActor
final class NetIncomeManager: ObservableObject {
    static let shared = NetIncomeManager()

    @Published var netIncome: Double = 0.0 {
        didSet { scheduleSave() }
    }

    private var saveTask: Task<Void, Never>?

    private var context: ModelContext { AppContainer.shared.mainContext }

    private init() {
        loadNetIncome()
    }

    func adjustNetIncome(by amount: Double, isIncome: Bool, isDeletion: Bool = false) {
        let adjustment = isDeletion ? -amount : amount
        netIncome += isIncome ? adjustment : -adjustment
    }

    func resetNetIncome() {
        do {
            try context.delete(model: NetIncomeEntity.self)
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
        do {
            let descriptor = FetchDescriptor<NetIncomeEntity>()
            let results = try context.fetch(descriptor)
            if let entity = results.first {
                entity.value = netIncome
            } else {
                let entity = NetIncomeEntity(value: netIncome)
                context.insert(entity)
            }
            try context.save()
        } catch {
            print("Failed to save net income: \(error.localizedDescription)")
        }
    }

    private func loadNetIncome() {
        do {
            let descriptor = FetchDescriptor<NetIncomeEntity>()
            let results = try context.fetch(descriptor)
            if let entity = results.first {
                netIncome = entity.value
            } else {
                let entity = NetIncomeEntity(value: 0.0)
                context.insert(entity)
                try context.save()
            }
        } catch {
            print("Failed to load net income: \(error.localizedDescription)")
        }
    }
}
