import SwiftUI

struct EditPredefinedTransactionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var transaction: PredefinedTransaction

    @State private var descriptionText: String
    @State private var amount: String
    @State private var selectedDay: String
    @State private var isIncome: Bool

    let days = Weekday.allNames

    @State private var showAlert = false
    @State private var alertMessage = ""

    init(transaction: PredefinedTransaction) {
        self.transaction = transaction
        _descriptionText = State(initialValue: transaction.desc ?? "")
        _amount = State(initialValue: String(transaction.amount))
        _selectedDay = State(initialValue: transaction.dayOfWeek ?? "Monday")
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
                            .accessibilityIdentifier("EditPredefined_DescriptionTextField")
                    }
                    Section(header: Text("Amount").font(.headline)) {
                        TextField("Enter amount", text: $amount)
                            .decimalInput($amount)
                            .accessibilityIdentifier("EditPredefined_AmountTextField")
                    }
                    Section(header: Text("Day of the Week").font(.headline)) {
                        Picker("Select Day", selection: $selectedDay) {
                            ForEach(days, id: \.self) { day in
                                Text(day)
                                    .accessibilityIdentifier("EditPredefined_DayPicker_\(day)")
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .accessibilityIdentifier("EditPredefined_DayPicker")
                    }
                    Section(header: Text("Transaction Type").font(.headline)) {
                        Picker("Type", selection: $isIncome) {
                            Text("Income").tag(true)
                            Text("Expense").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .accessibilityIdentifier("EditPredefined_TypePicker")
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Edit Predefined Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("EditPredefined_CancelButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { editPredefinedTransaction() }
                        .accessibilityIdentifier("EditPredefined_SaveButton")
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

    private func editPredefinedTransaction() {
        transaction.desc = descriptionText
        transaction.amount = Double(amount) ?? 0.0
        transaction.dayOfWeek = selectedDay
        transaction.isIncome = isIncome

        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to edit predefined transaction: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
