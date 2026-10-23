import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @Bindable var transaction: Transaction

    @State private var descriptionText: String
    @State private var amount: String
    @State private var selectedDay: String
    @State private var isIncome: Bool

    @EnvironmentObject var netIncomeManager: NetIncomeManager

    @State private var showAlert = false
    @State private var alertMessage = ""

    init(transaction: Transaction) {
        self.transaction = transaction
        _descriptionText = State(initialValue: transaction.desc ?? "")
        _amount = State(initialValue: transaction.amount.amountFieldText())
        _selectedDay = State(initialValue: transaction.dayOfWeek ?? "Monday")
        _isIncome = State(initialValue: transaction.isIncome)
    }

    var body: some View {
        NavigationStack {
            FinanceEntryForm(
                descriptionText: $descriptionText,
                amount: $amount,
                descriptionPrompt: "Enter description",
                descriptionIdentifier: "descriptionField",
                amountIdentifier: "amountField"
            ) {
                VStack(spacing: 16) {
                    WeekdayPickerCard(selection: $selectedDay, pickerID: "EditTransaction_DayPicker")
                    TransactionTypePicker(isIncome: $isIncome, identifier: "editTransactionTypePicker")
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("editCancelButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { editTransaction() }
                        .disabled(!isFormValid())
                        .accessibilityIdentifier("saveButton")
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

    private func editTransaction() {
        guard isFormValid() else { return }

        let oldAmount = transaction.amount
        let newAmount = Double(amount) ?? 0.0
        let wasIncome = transaction.isIncome

        transaction.desc = descriptionText
        transaction.amount = newAmount
        transaction.dayOfWeek = selectedDay
        transaction.isIncome = isIncome
        transaction.markLocalEdit()

        netIncomeManager.adjustNetIncome(by: oldAmount, isIncome: wasIncome, isDeletion: true)
        netIncomeManager.adjustNetIncome(by: newAmount, isIncome: isIncome, isDeletion: false)

        do {
            try modelContext.saveLocalChange()
            dismiss()
        } catch {
            alertMessage = "Failed to edit transaction: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
