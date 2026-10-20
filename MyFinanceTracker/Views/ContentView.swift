import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var cloud = FinanceCloud.shared

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
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: cloud.bannerState.needsAttention ? "exclamationmark.icloud" : "icloud")
                Text(cloud.bannerState.text)
            }
            .font(.caption)
            .foregroundStyle(cloud.bannerState.needsAttention ? Color.orange : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(.bar)
            .accessibilityElement(children: .combine)
            .allowsHitTesting(false)
        }
        .task {
            await FinanceCloud.shared.sync(in: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active || phase == .background else { return }
            Task { await FinanceCloud.shared.sync(in: modelContext) }
        }
    }
}
