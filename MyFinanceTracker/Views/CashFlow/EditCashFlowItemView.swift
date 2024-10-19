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

    private var isFormValid: Bool {
        guard let amt = Double(amount), amt > 0, !name.isEmpty else { return false }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Edit Cash Flow Item")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 20)

                CashFlowFormFields(name: $name, amount: $amount, isOwedToMe: $isOwedToMe)

                Button(action: editCashFlowItem) {
                    Text("Save Changes")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.accentColor : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!isFormValid)
                .padding(.horizontal)
            }
            .padding(.bottom, 50)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarItems(
            leading: Button("Cancel") { dismiss() }
        )
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
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
