import SwiftUI
import SwiftData

struct TransactionListView: View {
    let day: String
    let transactions: [Transaction]

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var netIncomeManager: NetIncomeManager

    var body: some View {
        Group {
            if transactions.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(FinanceTheme.accent)
                        Text("Nothing planned")
                            .font(.headline)
                        Text("Add income or an expense for \(day).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .financeCard(padding: 28)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(transactions, id: \.id) { transaction in
                            NavigationLink(destination: EditTransactionView(transaction: transaction)
                                            .environmentObject(netIncomeManager)) {
                                TransactionRowView(transaction: transaction, onDelete: {
                                    deleteTransaction(transaction)
                                })
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func deleteTransaction(_ transaction: Transaction) {
        netIncomeManager.adjustNetIncome(by: transaction.amount, isIncome: transaction.isIncome, isDeletion: true)
        modelContext.delete(transaction)
        modelContext.saveOrLog()
    }
}
