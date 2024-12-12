import SwiftUI

struct AddQuickAddTransactionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var descriptionText = ""
    @State private var amount = ""
    @State private var isIncome = true

    @State private var showAlert = false
    @State private var alertMessage = ""

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
            .navigationBarTitle("Add Quick Add Transaction", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { addQuickAddTransaction() }
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

    private func addQuickAddTransaction() {
        let newTransaction = QuickAddTransaction(context: viewContext)
        newTransaction.id = UUID()
        newTransaction.desc = descriptionText
        newTransaction.amount = Double(amount) ?? 0.0
        newTransaction.isIncome = isIncome

        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to add quick add transaction: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
