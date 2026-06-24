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
            _amount = State(initialValue: String(tx.amount))
            _selectedDay = State(initialValue: tx.repeatsEveryDay ? "Monday" : (tx.dayOfWeek ?? "Monday"))
            _repeatsEveryDay = State(initialValue: tx.repeatsEveryDay)
            _isIncome = State(initialValue: tx.isIncome)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                    Section(header: Text("Description").font(.headline)) {
                        TextField("Enter description", text: $descriptionText)
                            .accessibilityIdentifier("\(mode.identifierPrefix)_DescriptionTextField")
                    }
                    Section(header: Text("Amount").font(.headline)) {
                        TextField("Enter amount", text: $amount)
                            .decimalInput($amount)
                            .accessibilityIdentifier("\(mode.identifierPrefix)_AmountTextField")
                    }
                    Section {
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

                        if !repeatsEveryDay {
                            Picker("Day", selection: $selectedDay) {
                                ForEach(Weekday.allNames, id: \.self) { day in
                                    Text(day)
                                        .accessibilityIdentifier("\(mode.identifierPrefix)_DayPicker_\(day)")
                                }
                            }
                            .pickerStyle(.wheel)
                            .accessibilityIdentifier("\(mode.identifierPrefix)_DayPicker")
                        }
                    } header: {
                        Text("Schedule").font(.headline)
                    }
                    Section(header: Text("Transaction Type").font(.headline)) {
                        Picker("Type", selection: $isIncome) {
                            Text("Income").tag(true)
                            Text("Expense").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .accessibilityIdentifier("\(mode.identifierPrefix)_TypePicker")
                    }
            }
            .scrollContentBackground(.hidden)
            .financeBackground()
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

        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to save predefined transaction: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
