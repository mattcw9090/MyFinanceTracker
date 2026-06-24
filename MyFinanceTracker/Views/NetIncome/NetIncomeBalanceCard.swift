import SwiftUI

struct NetIncomeBalanceCard: View {
    @EnvironmentObject var netIncomeManager: NetIncomeManager

    var body: some View {
        NavigationLink {
            AdjustNetIncomeView()
        } label: {
            HStack(spacing: 12) {
                Text("Net Income")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("netIncomeLabel")

                Spacer()

                Text(netIncomeManager.netIncome.formattedAsCurrency())
                    .font(.title2)
                    .bold()
                    .foregroundColor(netIncomeManager.netIncome >= 0 ? .green : .red)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: netIncomeManager.netIncome)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("netIncomeValue")
        .accessibilityHint("Adjust net income")
    }
}
