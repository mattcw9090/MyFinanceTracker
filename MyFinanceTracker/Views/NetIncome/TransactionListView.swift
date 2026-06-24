import SwiftUI
import SwiftData

struct TransactionListView: View {
    let day: String
    let transactions: [Transaction]

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var netIncomeManager: NetIncomeManager

    var body: some View {
        VStack {
            if transactions.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        Text("No transactions for \(day).")
                            .foregroundColor(.gray)
                            .italic()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 25)
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
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
                    .padding(.horizontal, 15)
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
