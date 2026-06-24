import SwiftUI

struct NetIncomeBalanceCard: View {
    @EnvironmentObject var netIncomeManager: NetIncomeManager

    var body: some View {
        NavigationLink {
            AdjustNetIncomeView()
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("NET INCOME", systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.78))
                        .accessibilityIdentifier("netIncomeLabel")
                    Spacer()
                    Image(systemName: "slider.horizontal.2.square")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Text(netIncomeManager.netIncome.formattedAsCurrency())
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: netIncomeManager.netIncome)

                Text(netIncomeManager.netIncome >= 0 ? "You’re ahead for the week" : "Your planned spending is above income")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(
                LinearGradient(
                    colors: netIncomeManager.netIncome >= 0
                        ? [FinanceTheme.accent, FinanceTheme.accentDeep]
                        : [FinanceTheme.expense, Color(red: 0.58, green: 0.12, blue: 0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .shadow(color: FinanceTheme.accent.opacity(0.18), radius: 18, y: 9)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("netIncomeValue")
        .accessibilityHint("Adjust net income")
    }
}
