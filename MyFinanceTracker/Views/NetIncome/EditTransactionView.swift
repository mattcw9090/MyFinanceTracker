import SwiftUI
import CoreData

struct EditTransactionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var transaction: Transaction

    @State private var descriptionText: String
    @State private var amount: String
    @State private var selectedDay: String
    @State private var isIncome: Bool

    let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    @EnvironmentObject var netIncomeManager: NetIncomeManager

    @State private var showAlert = false
    @State private var alertMessage = ""

    init(transaction: Transaction) {
        self.transaction = transaction
        _descriptionText = State(initialValue: transaction.desc ?? "")
        _amount = State(initialValue: String(transaction.amount))
        _selectedDay = State(initialValue: transaction.dayOfWeek ?? "Monday")
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

                Section(header: Text("Day of the Week").font(.headline)) {
                    Picker("Select Day", selection: $selectedDay) {
                        ForEach(days, id: \.self) { day in
                            Text(day)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 150)
                }

                Section(header: Text("Transaction Type").font(.headline)) {
                    Picker("Type", selection: $isIncome) {
                        Text("Income").tag(true)
                        Text("Expense").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .tint(.accentColor)
                }
            }
            .navigationBarTitle("Edit Transaction", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    editTransaction()
                    dismiss()
                }
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

    private func editTransaction() {
        let oldAmount = transaction.amount
        let newAmount = Double(amount) ?? 0.0
        let wasIncome = transaction.isIncome

        transaction.desc = descriptionText
        transaction.amount = newAmount
        transaction.dayOfWeek = selectedDay
        transaction.isIncome = isIncome

        netIncomeManager.adjustNetIncome(by: oldAmount, isIncome: wasIncome, isDeletion: true)
        netIncomeManager.adjustNetIncome(by: newAmount, isIncome: isIncome, isDeletion: false)

        do {
            try viewContext.save()
        } catch {
            alertMessage = "Failed to edit transaction: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
