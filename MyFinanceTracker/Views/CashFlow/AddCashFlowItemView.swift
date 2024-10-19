import SwiftUI

struct AddCashFlowItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var amount = ""
    @State private var isOwedToMe: Bool
    @State private var showAlert = false
    @State private var alertMessage = ""

    init(isDefaultOwedToMe: Bool = true) {
        _isOwedToMe = State(initialValue: isDefaultOwedToMe)
    }

    private var isFormValid: Bool {
        guard let amt = Double(amount), amt > 0, !name.isEmpty else { return false }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Add Cash Flow Item")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 20)

                CashFlowFormFields(name: $name, amount: $amount, isOwedToMe: $isOwedToMe)

                Button(action: addCashFlowItem) {
                    Text("Save")
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
