import SwiftUI
import SwiftData

@main
struct MyFinanceTrackerApp: App {
    @StateObject var netIncomeManager = NetIncomeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(netIncomeManager)
        }
        .modelContainer(AppContainer.shared)
    }
}
