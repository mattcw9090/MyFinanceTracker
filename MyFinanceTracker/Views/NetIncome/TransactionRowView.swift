import SwiftUI
import CoreData

struct TransactionRowView: View {
    @ObservedObject var transaction: Transaction
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showAddToCashFlowConfirmation = false

    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.desc ?? "No Description")
                    .font(.system(size: 16, weight: .semibold))
                Text(transaction.isIncome ? "Income" : "Expense")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            Spacer()
            Text(formattedAmount())
                .foregroundColor(transaction.isIncome ? .green : .red)
                .font(.system(size: 16, weight: .bold))

            HStack(spacing: 12) {
                Button(action: markAsComplete) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .imageScale(.large)
                }
                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .foregroundColor(.red)
                        .imageScale(.large)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        // Remove additional padding and background to eliminate spacing
        // and lines between rows.
        // Just rely on the List to handle the layout.
        .alert(isPresented: $showAddToCashFlowConfirmation) {
            Alert(
                title: Text("Add to Cash Flow"),
                message: Text("Do you want to add this completed income transaction to the 'Who owes me' section?"),
                primaryButton: .default(Text("Yes")) {
                    addToCashFlow()
                    saveContext()
                },
                secondaryButton: .default(Text("No")) {
                    saveContext()
                }
            )
        }
    }

    private func formattedAmount() -> String {
        let amount = transaction.amount
        let formattedAmount = String(format: "%.2f", transaction.isIncome ? amount : -amount)
        return "$\(formattedAmount)"
    }

    private func markAsComplete() {
        transaction.isCompleted.toggle()
        if transaction.isIncome {
            showAddToCashFlowConfirmation = true
        } else {
            saveContext()
        }
    }

    private func addToCashFlow() {
        let cashFlowItem = CashFlowItem(context: viewContext)
        cashFlowItem.id = UUID()
        cashFlowItem.name = transaction.desc
        cashFlowItem.amount = transaction.amount
        cashFlowItem.isOwedToMe = true
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error.localizedDescription)")
        }
    }
}
