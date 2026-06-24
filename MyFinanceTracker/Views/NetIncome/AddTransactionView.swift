import SwiftUI
import SwiftData

struct AddTransactionView: View {
    let isIncome: Bool
    @Binding var selectedDay: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var descriptionText = ""
    @State private var amount = ""

    let days = Weekday.allNames

    @EnvironmentObject var netIncomeManager: NetIncomeManager

    @State private var showAlert = false
    @State private var alertMessage = ""

    @Query private var quickAddTransactions: [QuickAddTransaction]

    init(isIncome: Bool, selectedDay: Binding<String>) {
        self.isIncome = isIncome
        _selectedDay = selectedDay

        _quickAddTransactions = Query(
            filter: #Predicate<QuickAddTransaction> { $0.isIncome == isIncome },
            sort: \QuickAddTransaction.desc
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        FinanceSectionLabel(title: "When", detail: selectedDay)
                        Picker("Select Day", selection: $selectedDay) {
                            ForEach(days, id: \.self) { day in
                                Text(day)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 128)
                        .accessibilityIdentifier("AddTransaction_DayPicker")
                    }
                    .financeCard(padding: 18)

                    VStack(alignment: .leading, spacing: 16) {
                        FinanceSectionLabel(title: isIncome ? "Income details" : "Expense details")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description").font(.subheadline.weight(.semibold))
                            TextField(isIncome ? "e.g. Pay" : "e.g. Groceries", text: $descriptionText)
                                .financeField()
                                .textInputAutocapitalization(.sentences)
                                .accessibilityIdentifier("descriptionField")
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount").font(.subheadline.weight(.semibold))
                            HStack(spacing: 10) {
                                Text("$")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                TextField("0.00", text: $amount)
                                    .decimalInput($amount)
                                    .accessibilityIdentifier("amountField")
                            }
                            .financeField()
                        }
                    }
                    .financeCard(padding: 18)

                    if !quickAddTransactions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            FinanceSectionLabel(title: "Quick add", detail: "Tap to save")
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(quickAddTransactions, id: \.id) { transaction in
                                    Button { applyQuickAddTransaction(transaction) } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Image(systemName: "bolt.fill")
                                                .foregroundStyle(FinanceTheme.accent)
                                            Text(transaction.desc ?? "")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            Text(transaction.amount.formattedAsCurrency())
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(isIncome ? FinanceTheme.income : FinanceTheme.expense)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .financeCard(padding: 14)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("quickAdd_\(transaction.desc ?? "no_desc")")
                                }
                            }
                        }
                    }

                    Button(action: addTransaction) {
                        Text(isIncome ? "Add Income" : "Add Expense")
                    }
                    .buttonStyle(FinancePrimaryButtonStyle())
                    .disabled(!isFormValid())
                    .opacity(isFormValid() ? 1 : 0.45)
                    .accessibilityIdentifier("saveButton")
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .financeBackground()
            .navigationTitle(isIncome ? "Add Income" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelButton")
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

    private func applyQuickAddTransaction(_ template: QuickAddTransaction) {
        createTransaction(
            amount: template.amount,
            desc: template.desc ?? "",
            isIncome: template.isIncome
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
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to add transaction: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
