import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TransactionsView()
                .tabItem {
                    Image(systemName: "dollarsign.circle")
                    Text("Net Income")
                }

            CashFlowView()
                .tabItem {
                    Image(systemName: "banknote")
                    Text("Cash Flow")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
        }
        .accentColor(.purple)
    }
}
