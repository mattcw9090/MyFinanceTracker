import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var cloud = FinanceCloud.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NetIncomeTabView()
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("Net Income")
                }
                .tag(0)

            CashFlowTabView()
                .tabItem {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                    Text("Cash Flow")
                }
                .tag(1)

            SettingsTabView()
                .tabItem {
                    Image(systemName: "slider.horizontal.3")
                    Text("Settings")
                }
                .tag(2)
        }
        .tint(FinanceTheme.accent)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let prompt = financeSyncPrompt(isSignedIn: cloud.isSignedIn, notice: cloud.syncNotice) {
                FinanceSyncPrompt(kind: prompt) {
                    handleSyncPrompt(prompt)
                }
            }
        }
        .task {
            await FinanceCloud.shared.sync(in: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active || phase == .background else { return }
            Task { await FinanceCloud.shared.sync(in: modelContext) }
        }
    }

    private func handleSyncPrompt(_ prompt: FinanceSyncPromptKind) {
        switch prompt {
        case .signIn, .accountBlocked:
            selectedTab = 2
        case .uploadsNotSending:
            Task { await cloud.sync(in: modelContext) }
        }
    }
}

private struct FinanceSyncPrompt: View {
    let kind: FinanceSyncPromptKind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(FinanceTheme.amber)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Text(actionTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FinanceTheme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private var title: String {
        switch kind {
        case .signIn:
            return "Sign in to sync"
        case .accountBlocked:
            return "This account can't sync"
        case .uploadsNotSending:
            return "Changes aren't uploading"
        }
    }

    private var actionTitle: String {
        switch kind {
        case .signIn:
            return "Sign in"
        case .accountBlocked:
            return "Review"
        case .uploadsNotSending:
            return "Try again"
        }
    }

    private var identifier: String {
        switch kind {
        case .signIn:
            return "FinanceSyncPrompt_SignIn"
        case .accountBlocked:
            return "FinanceSyncPrompt_Account"
        case .uploadsNotSending:
            return "FinanceSyncPrompt_Retry"
        }
    }
}
