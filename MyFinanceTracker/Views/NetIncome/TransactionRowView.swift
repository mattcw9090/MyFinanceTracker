import SwiftUI
import SwiftData

struct TransactionRowView: View {
    @Bindable var transaction: Transaction

    var onComplete: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.isIncome ? "arrow.down.left" : "arrow.up.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(transaction.isIncome ? FinanceTheme.income : FinanceTheme.expense)
                .frame(width: 38, height: 38)
                .background(
                    (transaction.isIncome ? FinanceTheme.income : FinanceTheme.expense).opacity(0.11),
                    in: Circle()
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.desc ?? "No Description")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("transactionDescription")
                Text(transaction.isIncome ? "Income" : "Expense")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("transactionType")
            }
            Spacer()
            Text(signedAmount.formattedAsCurrency())
                .foregroundStyle(transaction.isIncome ? FinanceTheme.income : FinanceTheme.expense)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .accessibilityIdentifier("transactionAmount")

            HStack(spacing: 8) {
                Button(action: onComplete) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(FinanceTheme.income)
                        .frame(width: 32, height: 32)
                        .background(FinanceTheme.income.opacity(0.1), in: Circle())
                }
                .accessibilityIdentifier("markCompleteButton")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                .accessibilityIdentifier("deleteButton")
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .financeCard(padding: 14)
    }

    private var signedAmount: Double {
        let magnitude = abs(transaction.amount)
        return transaction.isIncome ? magnitude : -magnitude
    }
}
