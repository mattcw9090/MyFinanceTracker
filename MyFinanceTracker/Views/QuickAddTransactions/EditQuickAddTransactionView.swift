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
        NavigationView {
            Form {
                Section(header: Text("Description").font(.headline)) {
                    TextField("Enter description", text: $descriptionText)
                        .padding(.vertical, 8)
                }
                Section(header: Text("Amount").font(.headline)) {
                    TextField("Enter amount", text: $amount)
                        .keyboardType(.decimalPad)
                        .padding(.vertical, 8)
                        .onReceive(amount.publisher.collect()) { newValue in
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            if filtered != newValue {
                                amount = String(filtered.prefix(10))
                            }
                        }
                }
                Section(header: Text("Transaction Type").font(.headline)) {
                    Picker("Type", selection: $isIncome) {
                        Text("Income").tag(true)
                        Text("Expense").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationBarTitle("Edit Quick Add Transaction", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { editQuickAddTransaction() }
                    .disabled(!isFormValid())
            )
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
            .accentColor(.purple)
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
