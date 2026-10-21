import SwiftUI

struct CashFlowRowView: View {
    @Bindable var item: CashFlowItem
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isSettled ? "checkmark" : FinanceMark.symbol(isIncome: item.isOwedToMe))
                .font(.body.weight(.semibold))
                .foregroundStyle(item.isSettled ? Color.secondary : amountColor)
                .frame(width: 32, height: 32)
                .accessibilityIdentifier("cashFlowType")
                .accessibilityLabel(item.isOwedToMe ? "Owed to me" : "I owe")

            Text(item.name ?? "Unnamed")
                .font(.subheadline.weight(.semibold))
                .strikethrough(item.isSettled)
                .foregroundStyle(item.isSettled ? .secondary : .primary)
                .multilineTextAlignment(.leading)
                .accessibilityIdentifier("cashFlowName")

            Spacer(minLength: 8)

            Text(signedAmount.formattedAsCurrency())
                .font(.subheadline.weight(.bold))
                .foregroundStyle(amountColor)
                .strikethrough(item.isSettled)
                .monospacedDigit()
                .accessibilityIdentifier("cashFlowAmount")
        }
        .financeCard(padding: 14)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .opacity(item.isSettled ? 0.7 : 1.0)
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
