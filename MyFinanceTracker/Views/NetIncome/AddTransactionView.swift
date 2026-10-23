import SwiftUI
import SwiftData

struct AddTransactionView: View {
    let isIncome: Bool
    @Binding var selectedDay: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var descriptionText = ""
    @State private var amount = ""

    @EnvironmentObject var netIncomeManager: NetIncomeManager

    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            FinanceEntryForm(
                descriptionText: $descriptionText,
                amount: $amount,
                descriptionPrompt: isIncome ? "e.g. Pay" : "e.g. Groceries",
                descriptionIdentifier: "descriptionField",
                amountIdentifier: "amountField"
            ) {
                WeekdayPickerCard(selection: $selectedDay, pickerID: "AddTransaction_DayPicker")
            }
            .navigationTitle(isIncome ? "Add Income" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { addTransaction() }
                        .disabled(!isFormValid())
                        .accessibilityIdentifier("saveButton")
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func isFormValid() -> Bool {
        guard let amt = Double(amount), amt > 0, !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        return true
    }

    private func addTransaction() {
        createTransaction(
            amount: Double(amount) ?? 0.0,
            desc: descriptionText,
            isIncome: isIncome
        )
    }

    private func createTransaction(amount: Double, desc: String, isIncome: Bool) {
        let newTransaction = Transaction(
            desc: desc,
            amount: amount,
            dayOfWeek: selectedDay,
            isCompleted: false,
            isIncome: isIncome
        )
        modelContext.insert(newTransaction)

        netIncomeManager.adjustNetIncome(by: amount, isIncome: isIncome, isDeletion: false)

        do {
            try modelContext.saveLocalChange()
            dismiss()
        } catch {
            alertMessage = "Failed to add transaction: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
