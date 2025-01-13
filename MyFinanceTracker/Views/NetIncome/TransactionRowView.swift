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
                    .accessibilityIdentifier("transactionDescription")
                Text(transaction.isIncome ? "Income" : "Expense")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .accessibilityIdentifier("transactionType")
            }
            Spacer()
            Text(formattedAmount())
                .foregroundColor(transaction.isIncome ? .green : .red)
                .font(.system(size: 16, weight: .bold))
                .accessibilityIdentifier("transactionAmount")

            HStack(spacing: 12) {
                Button(action: markAsComplete) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .imageScale(.large)
                }
                .accessibilityIdentifier("markCompleteButton")

                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .foregroundColor(.red)
                        .imageScale(.large)
                }
                .accessibilityIdentifier("deleteButton")
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
        )
        .padding(.vertical, 10)
        .alert(isPresented: $showAddToCashFlowConfirmation) {
            Alert(
                title: Text("Add to Cash Flow"),
                message: Text("Do you want to add this completed income transaction to the 'Who owes me' section?"),
                primaryButton: .default(Text("Yes")) {
                    addToCashFlow()
                    toggleIsCompleted()
                },
                secondaryButton: .default(Text("No")) {
                    toggleIsCompleted()
                }
            )
        }
    }

    /// Formats the transaction amount for display.
    private func formattedAmount() -> String {
        let amount = transaction.amount
        let formattedAmount = String(format: "%.2f", transaction.isIncome ? amount : -amount)
        return "$\(formattedAmount)"
    }

    /// Handles the action when the "Mark as Complete" button is tapped.
    private func markAsComplete() {
        if transaction.isIncome {
            // Show confirmation alert for income transactions.
            showAddToCashFlowConfirmation = true
        } else {
            // Directly mark as complete for expense transactions.
            toggleIsCompleted()
        }
    }

    /// Toggles the `isCompleted` property and saves the context.
    private func toggleIsCompleted() {
        transaction.isCompleted.toggle()
        saveContext()
    }

    /// Adds the transaction to the cash flow section.
    private func addToCashFlow() {
        let cashFlowItem = CashFlowItem(context: viewContext)
        cashFlowItem.id = UUID()
        cashFlowItem.name = transaction.desc ?? "Unnamed Transaction"
        cashFlowItem.amount = transaction.amount
        cashFlowItem.isOwedToMe = true
    }

    /// Saves the current state of the managed object context.
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error.localizedDescription)")
        }
    }
}
