import SwiftUI

@main
struct MyFinanceTrackerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject var netIncomeManager = NetIncomeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(netIncomeManager)
        }
    }
}
