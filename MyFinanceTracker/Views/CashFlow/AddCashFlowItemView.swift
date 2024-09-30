import SwiftUI

struct AddCashFlowItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var amount = ""
    @State private var isOwedToMe: Bool

    @State private var showAlert = false
    @State private var alertMessage = ""

    // Initializer with parameter to set default isOwedToMe
    init(isDefaultOwedToMe: Bool = true) {
        _isOwedToMe = State(initialValue: isDefaultOwedToMe)
    }

    var body: some View {
        Form {
            Section(header: Text("Name")) {
                TextField("Enter name", text: $name)
            }
            Section(header: Text("Amount")) {
                TextField("Enter amount", text: $amount)
                    .keyboardType(.decimalPad)
                    .onReceive(amount.publisher.collect()) { newValue in
                        let filtered = newValue.filter { "0123456789.".contains($0) }
                        if filtered != newValue {
                            amount = String(filtered.prefix(10))
                        }
                    }
            }
            Section(header: Text("Cash Flow Type")) {
                Picker("Type", selection: $isOwedToMe) {
                    Text("Owed to me").tag(true)
                    Text("I owe").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .navigationBarTitle("Add Cash Flow Item", displayMode: .inline)
        .navigationBarItems(
            leading: Button("Cancel") { dismiss() },
            trailing: Button("Save") { addCashFlowItem() }
                .disabled(!isFormValid())
        )
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func isFormValid() -> Bool {
        guard let amt = Double(amount), amt > 0, !name.isEmpty else {
            return false
        }
        return true
    }

    private func addCashFlowItem() {
        let newItem = CashFlowItem(context: viewContext)
        newItem.id = UUID()
        newItem.name = name
        newItem.amount = Double(amount) ?? 0.0
        newItem.isOwedToMe = isOwedToMe

        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to add cash flow item: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
