import SwiftUI

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

    @Environment(\.managedObjectContext) private var viewContext
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
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemBackground)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    Text(mode.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                        .foregroundColor(.primary)

                    CashFlowFormFields(name: $name, amount: $amount, isOwedToMe: $isOwedToMe)
                        .padding(.horizontal)

                    Button(action: commit) {
                        Text(mode.saveButtonTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color.accentColor : Color.gray)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    .disabled(!isFormValid)
                    .padding(.horizontal)
                }
                .padding(.bottom, 50)
            }
        }
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
            target = CashFlowItem(context: viewContext)
            target.id = UUID()
        case .edit(let item):
            target = item
        }

        target.name = name
        target.amount = Double(amount) ?? 0.0
        target.isOwedToMe = isOwedToMe

        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to save cash flow item: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
