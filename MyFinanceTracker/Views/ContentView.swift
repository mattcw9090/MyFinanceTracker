import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NetIncomeTabView()
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("Net Income")
                }

            CashFlowTabView()
                .tabItem {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                    Text("Cash Flow")
                }

            SettingsTabView()
                .tabItem {
                    Image(systemName: "slider.horizontal.3")
                    Text("Settings")
                }
        }
        .tint(FinanceTheme.accent)
    }
}
