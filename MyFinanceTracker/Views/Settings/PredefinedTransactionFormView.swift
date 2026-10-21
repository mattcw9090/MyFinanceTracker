import SwiftUI
import SwiftData

struct PredefinedTransactionFormView: View {
    enum Mode {
        case add
        case edit(PredefinedTransaction)

        var identifierPrefix: String {
            switch self {
            case .add: return "AddPredefined"
            case .edit: return "EditPredefined"
            }
        }

        var title: String {
            switch self {
            case .add: return "Add Predefined Transaction"
            case .edit: return "Edit Predefined Transaction"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var descriptionText: String
    @State private var amount: String
    @State private var selectedDay: String
    @State private var repeatsEveryDay: Bool
    @State private var isIncome: Bool
    @State private var showAlert = false
    @State private var alertMessage = ""

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .add:
            _descriptionText = State(initialValue: "")
            _amount = State(initialValue: "")
            _selectedDay = State(initialValue: "Monday")
            _repeatsEveryDay = State(initialValue: false)
            _isIncome = State(initialValue: true)
        case .edit(let tx):
            _descriptionText = State(initialValue: tx.desc ?? "")
            _amount = State(initialValue: tx.amount.amountFieldText())
            _selectedDay = State(initialValue: tx.repeatsEveryDay ? "Monday" : (tx.dayOfWeek ?? "Monday"))
            _repeatsEveryDay = State(initialValue: tx.repeatsEveryDay)
            _isIncome = State(initialValue: tx.isIncome)
        }
    }

    var body: some View {
        NavigationStack {
            FinanceEntryForm(
                descriptionText: $descriptionText,
                amount: $amount,
                descriptionPrompt: "Enter description",
                descriptionIdentifier: "\(mode.identifierPrefix)_DescriptionTextField",
                amountIdentifier: "\(mode.identifierPrefix)_AmountTextField"
            ) {
                VStack(spacing: 16) {
                    Toggle(isOn: $repeatsEveryDay.animation(.snappy)) {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Every day")
                                Text("Add this transaction to all seven days")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "repeat.circle.fill")
                                .foregroundStyle(FinanceTheme.accent)
                        }
                    }
                    .tint(FinanceTheme.accent)
                    .accessibilityIdentifier("\(mode.identifierPrefix)_EveryDayToggle")
                    .financeCard(padding: 18)

                    if !repeatsEveryDay {
                        WeekdayPickerCard(
                            selection: $selectedDay,
                            pickerID: "\(mode.identifierPrefix)_DayPicker"
                        )
                    }

                    TransactionTypePicker(
                        isIncome: $isIncome,
                        identifier: "\(mode.identifierPrefix)_TypePicker"
                    )
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("\(mode.identifierPrefix)_CancelButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { commit() }
                        .accessibilityIdentifier("\(mode.identifierPrefix)_SaveButton")
                        .disabled(!isFormValid)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
        }
    }

    private var isFormValid: Bool {
        guard let amt = Double(amount), amt > 0, !descriptionText.isEmpty else { return false }
        return true
    }

    private func commit() {
        let target: PredefinedTransaction
        switch mode {
        case .add:
            target = PredefinedTransaction()
            modelContext.insert(target)
        case .edit(let tx):
            target = tx
        }

        target.desc = descriptionText
        target.amount = Double(amount) ?? 0.0
        target.dayOfWeek = repeatsEveryDay ? PredefinedTransaction.everyDaySchedule : selectedDay
        target.isIncome = isIncome
        target.markLocalEdit()

        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to save predefined transaction: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
