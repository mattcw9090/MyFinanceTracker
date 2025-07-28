import SwiftUI
import CoreData

struct TransactionRowView: View {
    @ObservedObject var transaction: Transaction
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showAddToCashFlowConfirmation = false
    @State private var showAdditionalCostInput = false
    @State private var additionalCostString: String = ""
    @State private var splitNames: [String] = []

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
                    showAdditionalCostInput = true
                },
                secondaryButton: .cancel {
                    toggleIsCompleted()
                }
            )
        }
        .sheet(isPresented: $showAdditionalCostInput) {
            NavigationView {
                Form {
                    Section(header: Text("Additional Court Cost")) {
                        TextField("Enter amount", text: $additionalCostString)
                            .keyboardType(.decimalPad)
                    }
                    Section(header: Text("Split")) {
                        // Only an Add button; entries with blank names are ignored
                        Button(action: {
                            splitNames.append("")
                        }) {
                            Label("Add Person", systemImage: "plus.circle")
                        }
                        ForEach(splitNames.indices, id: \.self) { index in
                            TextField("Name", text: $splitNames[index])
                        }
                    }
                }
                .navigationBarTitle("Add Court Cost", displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showAdditionalCostInput = false
                        toggleIsCompleted()
                    },
                    trailing: Button("Add") {
                        addToCashFlow()
                        toggleIsCompleted()
                        showAdditionalCostInput = false
                    }
                )
            }
        }
    }

    /// Formats the transaction amount for display.
    private func formattedAmount() -> String {
        let amount = abs(transaction.amount)
        let formattedAmount = String(format: "%.2f", amount)
        return "\(transaction.isIncome ? "$" : "-$")\(formattedAmount)"
    }

    /// Handles the action when the "Mark as Complete" button is tapped.
    private func markAsComplete() {
        if transaction.isIncome {
            showAddToCashFlowConfirmation = true
        } else {
            toggleIsCompleted()
        }
    }

    /// Toggles the `isCompleted` property and saves the context.
    private func toggleIsCompleted() {
        transaction.isCompleted.toggle()
        saveContext()
    }

    /// Adds the transaction to the cash flow section, splitting among names if provided.
    private func addToCashFlow() {
        let extra = Double(additionalCostString) ?? 0
        let total = transaction.amount + extra
        let names = splitNames
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let share = names.isEmpty ? total : total / Double(names.count)

        if names.isEmpty {
            let item = CashFlowItem(context: viewContext)
            item.id = UUID()
            item.name = transaction.desc ?? "Unnamed Transaction"
            item.amount = total
            item.isOwedToMe = true
        } else {
            for name in names {
                let item = CashFlowItem(context: viewContext)
                item.id = UUID()
                item.name = name
                item.amount = share
                item.isOwedToMe = true
            }
        }
        saveContext()
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
