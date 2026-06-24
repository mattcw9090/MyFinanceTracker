import SwiftUI

struct EditQuickAddTransactionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var transaction: QuickAddTransaction

    @State private var descriptionText: String
    @State private var amount: String
    @State private var isIncome: Bool

    @State private var showAlert = false
    @State private var alertMessage = ""

    init(transaction: QuickAddTransaction) {
        self.transaction = transaction
        _descriptionText = State(initialValue: transaction.desc ?? "")
        _amount = State(initialValue: String(transaction.amount))
        _isIncome = State(initialValue: transaction.isIncome)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemBackground)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Form {
                    Section(header: Text("Description").font(.headline)) {
                        TextField("Enter description", text: $descriptionText)
                            .accessibilityIdentifier("EditQuickAdd_DescriptionTextField")
                    }
                    Section(header: Text("Amount").font(.headline)) {
                        TextField("Enter amount", text: $amount)
                            .decimalInput($amount)
                            .accessibilityIdentifier("EditQuickAdd_AmountTextField")
                    }
                    Section(header: Text("Transaction Type").font(.headline)) {
                        Picker("Type", selection: $isIncome) {
                            Text("Income").tag(true)
                            Text("Expense").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .accessibilityIdentifier("EditQuickAdd_TypePicker")
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Edit Quick Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("EditQuickAdd_CancelButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { editQuickAddTransaction() }
                        .accessibilityIdentifier("EditQuickAdd_SaveButton")
                        .disabled(!isFormValid())
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
        }
    }

    private func isFormValid() -> Bool {
        guard let amt = Double(amount), amt > 0, !descriptionText.isEmpty else {
            return false
        }
        return true
    }

    private func editQuickAddTransaction() {
        transaction.desc = descriptionText
        transaction.amount = Double(amount) ?? 0.0
        transaction.isIncome = isIncome

        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to edit quick add transaction: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
