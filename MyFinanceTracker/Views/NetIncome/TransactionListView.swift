import SwiftUI

struct TransactionListView: View {
    let day: String
    let transactions: [Transaction]

    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var netIncomeManager: NetIncomeManager

    var body: some View {
        List {
            if transactions.isEmpty {
                Text("No transactions for \(day).")
                    .foregroundColor(.gray)
                    .italic()
                    .padding()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(transactions, id: \.id) { transaction in
                    ZStack {
                        NavigationLink(destination: EditTransactionView(transaction: transaction)
                                        .environment(\.managedObjectContext, viewContext)
                                        .environmentObject(netIncomeManager)) {
                            EmptyView()
                        }
                        .opacity(0)

                        TransactionRowView(transaction: transaction, onDelete: {
                            deleteTransaction(transaction)
                        })
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
    }

    private func deleteTransaction(_ transaction: Transaction) {
        netIncomeManager.adjustNetIncome(by: transaction.amount, isIncome: transaction.isIncome, isDeletion: true)
        viewContext.delete(transaction)

        do {
            try viewContext.save()
        } catch {
            print("Error deleting transaction: \(error.localizedDescription)")
        }
    }
}
