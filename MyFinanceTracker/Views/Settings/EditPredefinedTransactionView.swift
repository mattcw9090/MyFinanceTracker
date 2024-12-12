import SwiftUI

struct EditPredefinedTransactionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var transaction: PredefinedTransaction

    @State private var descriptionText: String
    @State private var amount: String
    @State private var selectedDay: String
    @State private var isIncome: Bool

    let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

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
        NavigationView {
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
                    }
                    Section(header: Text("Amount").font(.headline)) {
                        TextField("Enter amount", text: $amount)
                            .keyboardType(.decimalPad)
                            .onReceive(amount.publisher.collect()) { newValue in
                                let filtered = newValue.filter { "0123456789.".contains($0) }
                                if filtered != newValue {
                                    amount = String(filtered.prefix(10))
                                }
                            }
                    }
                    Section(header: Text("Day of the Week").font(.headline)) {
                        Picker("Select Day", selection: $selectedDay) {
                            ForEach(days, id: \.self) { day in
                                Text(day)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    Section(header: Text("Transaction Type").font(.headline)) {
                        Picker("Type", selection: $isIncome) {
                            Text("Income").tag(true)
                            Text("Expense").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationBarTitle("Edit Predefined Transaction", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { editPredefinedTransaction() }
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
