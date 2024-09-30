import SwiftUI
import CoreData

struct TransactionRowView: View {
    @ObservedObject var transaction: Transaction
    @Environment(\.managedObjectContext) private var viewContext

    var onEdit: () -> Void
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
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.orange)
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
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
    }

    private func formattedAmount() -> String {
        let amount = transaction.amount
        let formattedAmount = String(format: "%.2f", transaction.isIncome ? amount : -amount)
        return "$\(formattedAmount)"
    }

    private func markAsComplete() {
        transaction.isCompleted.toggle()
        do {
            try viewContext.save()
        } catch {
            print("Error marking transaction as complete: \(error.localizedDescription)")
        }
    }
}
