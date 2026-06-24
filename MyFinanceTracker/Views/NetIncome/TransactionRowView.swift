import SwiftUI
import SwiftData

struct TransactionRowView: View {
    @Bindable var transaction: Transaction
    @Environment(\.modelContext) private var modelContext

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
            Text(signedAmount.formattedAsCurrency())
                .foregroundColor(transaction.isIncome ? .green : .red)
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
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
            NavigationStack {
                Form {
                    Section(header: Text("Additional Court Cost")) {
                        TextField("Enter amount", text: $additionalCostString)
                            .decimalInput($additionalCostString)
                    }
                    Section(header: Text("Split")) {
                        Button {
                            splitNames.append("")
                        } label: {
                            Label("Add Person", systemImage: "plus.circle")
                        }
                        ForEach(splitNames.indices, id: \.self) { index in
                            TextField("Name", text: $splitNames[index])
                        }
                    }
                }
                .navigationTitle("Add Court Cost")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            showAdditionalCostInput = false
                            toggleIsCompleted()
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add") {
                            addToCashFlow()
                            toggleIsCompleted()
                            showAdditionalCostInput = false
                        }
                    }
                }
            }
        }
    }

    private var signedAmount: Double {
        let magnitude = abs(transaction.amount)
        return transaction.isIncome ? magnitude : -magnitude
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
            modelContext.insert(CashFlowItem(
                name: transaction.desc ?? "Unnamed Transaction",
                amount: total,
                isOwedToMe: true
            ))
        } else {
            for name in names {
                modelContext.insert(CashFlowItem(
                    name: name,
                    amount: share,
                    isOwedToMe: true
                ))
            }
        }
        saveContext()
    }

    private func saveContext() {
        modelContext.saveOrLog()
    }
}
