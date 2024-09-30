import SwiftUI

struct TransactionListView: View {
    let day: String
    let transactions: [Transaction]

    @Environment(\.managedObjectContext) private var viewContext
    @State private var transactionToEdit: Transaction?
    @EnvironmentObject var netIncomeManager: NetIncomeManager

    var body: some View {
        List {
            if transactions.isEmpty {
                Text("No transactions for \(day).")
                    .foregroundColor(.gray)
                    .italic()
                    .padding()
            } else {
                ForEach(transactions, id: \.id) { transaction in
                    TransactionRowView(transaction: transaction, onEdit: {
                        transactionToEdit = transaction
                    }, onDelete: {
                        deleteTransaction(transaction)
                    })
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(PlainListStyle())
        .sheet(item: $transactionToEdit) { transaction in
            EditTransactionView(transaction: transaction)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(netIncomeManager)
        }
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
