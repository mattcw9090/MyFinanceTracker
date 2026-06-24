import SwiftUI

struct CashFlowRowView: View {
    @Bindable var item: CashFlowItem
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: item.isSettled ? "checkmark" : (item.isOwedToMe ? "arrow.down.left" : "arrow.up.right"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(item.isSettled ? Color.secondary : amountColor)
                    .frame(width: 38, height: 38)
                    .background((item.isSettled ? Color.secondary : amountColor).opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name ?? "Unnamed")
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(item.isSettled)
                        .foregroundStyle(item.isSettled ? .secondary : .primary)
                        .accessibilityIdentifier("cashFlowName")
                    Text(item.isOwedToMe ? "Owed to Me" : "I Owe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("cashFlowType")
                }
                Spacer()
                Text(signedAmount.formattedAsCurrency())
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(amountColor)
                    .strikethrough(item.isSettled)
                    .monospacedDigit()
                    .accessibilityIdentifier("cashFlowAmount")
            }
            .financeCard(padding: 14)
            .opacity(item.isSettled ? 0.55 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var signedAmount: Double {
        let magnitude = abs(item.amount)
        return item.isOwedToMe ? magnitude : -magnitude
    }

    private var amountColor: Color {
        if item.isSettled { return .secondary }
        return item.isOwedToMe ? FinanceTheme.income : FinanceTheme.expense
    }
}
