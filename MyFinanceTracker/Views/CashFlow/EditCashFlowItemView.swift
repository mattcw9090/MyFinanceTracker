import SwiftUI

struct EditCashFlowItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var item: CashFlowItem

    @State private var name: String
    @State private var amount: String
    @State private var isOwedToMe: Bool

    @State private var showAlert = false
    @State private var alertMessage = ""

    init(item: CashFlowItem) {
        self.item = item
        _name = State(initialValue: item.name ?? "")
        _amount = State(initialValue: String(item.amount))
        _isOwedToMe = State(initialValue: item.isOwedToMe)
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
        .navigationBarTitle("Edit Cash Flow Item", displayMode: .inline)
        .navigationBarItems(
            leading: Button("Cancel") { dismiss() },
            trailing: Button("Save") { editCashFlowItem() }
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

    private func editCashFlowItem() {
        item.name = name
        item.amount = Double(amount) ?? 0.0
        item.isOwedToMe = isOwedToMe

        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to edit cash flow item: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
