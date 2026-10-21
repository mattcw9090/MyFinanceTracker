import SwiftUI
import SwiftData

struct TransactionRowView: View {
    @Bindable var transaction: Transaction

    var onOpen: () -> Void
    var onComplete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: FinanceMark.symbol(isIncome: transaction.isIncome))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(transaction.isIncome ? FinanceTheme.income : FinanceTheme.expense)
                    .frame(width: 32, height: 32)
                    .accessibilityLabel(transaction.isIncome ? "Income" : "Expense")
                Text(transaction.desc ?? "No Description")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .accessibilityIdentifier("transactionDescription")
                Spacer(minLength: 4)
                Text(signedAmount.formattedAsCurrency())
                    .foregroundStyle(transaction.isIncome ? FinanceTheme.income : FinanceTheme.expense)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .accessibilityIdentifier("transactionAmount")
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            Button(action: onComplete) {
                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(FinanceTheme.incomeFill, in: Circle())
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("markCompleteButton")
            .accessibilityLabel("Tick")
        }
        .financeCard(padding: 10)
    }

    private var signedAmount: Double {
        let magnitude = abs(transaction.amount)
        return transaction.isIncome ? magnitude : -magnitude
    }
}
