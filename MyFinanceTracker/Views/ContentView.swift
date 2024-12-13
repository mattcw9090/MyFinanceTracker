import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NetIncomeTabView()
                .tabItem {
                    Image(systemName: "dollarsign.circle")
                    Text("Net Income")
                }

            CashFlowTabView()
                .tabItem {
                    Image(systemName: "banknote")
                    Text("Cash Flow")
                }

            SettingsTabView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
        }
        .accentColor(.blue)
    }
}
