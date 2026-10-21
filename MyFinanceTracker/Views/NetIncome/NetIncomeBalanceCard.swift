import SwiftUI

struct NetIncomeBalanceCard: View {
    @EnvironmentObject var netIncomeManager: NetIncomeManager

    var body: some View {
        NavigationLink {
            AdjustNetIncomeView()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("NET INCOME", systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.85))
                        .accessibilityIdentifier("netIncomeLabel")
                    Spacer()
                    Image(systemName: "slider.horizontal.2.square")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Text(netIncomeManager.netIncome.formattedAsCurrency())
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: netIncomeManager.netIncome)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(statusLine)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.88))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [FinanceTheme.accent, FinanceTheme.accentDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .shadow(color: FinanceTheme.accent.opacity(0.18), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("netIncomeValue")
        .accessibilityHint("Adjust net income")
    }

    private var statusLine: String {
        let value = netIncomeManager.netIncome
        if abs(value) < 0.005 {
            return "Even for the week"
        }
        if value > 0 {
            return "You’re ahead for the week"
        }
        return "Your planned spending is above income"
    }
}
