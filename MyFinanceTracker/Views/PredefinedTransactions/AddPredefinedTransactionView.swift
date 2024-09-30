import SwiftUI

struct AddPredefinedTransactionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var descriptionText = ""
    @State private var amount = ""
    @State private var selectedDay = "Monday"
    @State private var isIncome = true

    let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    @State private var showAlert = false
    @State private var alertMessage = ""

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
            .navigationBarTitle("Add Predefined Transaction", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { addPredefinedTransaction() }
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

    private func addPredefinedTransaction() {
        let newTransaction = PredefinedTransaction(context: viewContext)
        newTransaction.id = UUID()
        newTransaction.amount = Double(amount) ?? 0.0
        newTransaction.desc = descriptionText
        newTransaction.dayOfWeek = selectedDay
        newTransaction.isIncome = isIncome

        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to add predefined transaction: \(error.localizedDescription)"
            showAlert = true
        }
    }
}