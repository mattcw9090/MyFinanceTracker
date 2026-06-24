import SwiftUI
import SwiftData

struct CashFlowItemFormView: View {
    enum Mode {
        case add(defaultOwedToMe: Bool)
        case edit(CashFlowItem)

        var title: String {
            switch self {
            case .add: return "Add Cash Flow Item"
            case .edit: return "Edit Cash Flow Item"
            }
        }

        var saveButtonTitle: String {
            switch self {
            case .add: return "Save"
            case .edit: return "Save Changes"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var name: String
    @State private var amount: String
    @State private var isOwedToMe: Bool
    @State private var showAlert = false
    @State private var alertMessage = ""

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .add(let defaultOwedToMe):
            _name = State(initialValue: "")
            _amount = State(initialValue: "")
            _isOwedToMe = State(initialValue: defaultOwedToMe)
        case .edit(let item):
            _name = State(initialValue: item.name ?? "")
            _amount = State(initialValue: String(item.amount))
            _isOwedToMe = State(initialValue: item.isOwedToMe)
        }
    }

    private var isFormValid: Bool {
        guard let amt = Double(amount), amt > 0, !name.isEmpty else { return false }
        return true
    }

    var body: some View {
        ScrollView {
                VStack(spacing: 18) {
                    CashFlowFormFields(name: $name, amount: $amount, isOwedToMe: $isOwedToMe)
                        .padding(.horizontal)
                        .padding(.top, 12)

                    Button(action: commit) {
                        Text(mode.saveButtonTitle)
                    }
                    .buttonStyle(FinancePrimaryButtonStyle())
                    .disabled(!isFormValid)
                    .opacity(isFormValid ? 1 : 0.45)
                    .padding(.horizontal)
                }
                .padding(.bottom, 50)
        }
        .financeBackground()
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func commit() {
        let target: CashFlowItem
        switch mode {
        case .add:
            target = CashFlowItem()
            modelContext.insert(target)
        case .edit(let item):
            target = item
        }

        target.name = name
        target.amount = Double(amount) ?? 0.0
        target.isOwedToMe = isOwedToMe

        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to save cash flow item: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
