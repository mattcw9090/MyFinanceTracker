import SwiftUI
import SwiftData

struct QuickAddTransactionFormView: View {
    enum Mode {
        case add
        case edit(QuickAddTransaction)

        var identifierPrefix: String {
            switch self {
            case .add: return "AddQuickAdd"
            case .edit: return "EditQuickAdd"
            }
        }

        var title: String {
            switch self {
            case .add: return "Add Quick Add Transaction"
            case .edit: return "Edit Quick Add Transaction"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var descriptionText: String
    @State private var amount: String
    @State private var isIncome: Bool
    @State private var showAlert = false
    @State private var alertMessage = ""

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .add:
            _descriptionText = State(initialValue: "")
            _amount = State(initialValue: "")
            _isIncome = State(initialValue: true)
        case .edit(let tx):
            _descriptionText = State(initialValue: tx.desc ?? "")
            _amount = State(initialValue: String(tx.amount))
            _isIncome = State(initialValue: tx.isIncome)
        }
    }

    var body: some View {
        NavigationStack {
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
                            .accessibilityIdentifier("\(mode.identifierPrefix)_DescriptionTextField")
                    }
                    Section(header: Text("Amount").font(.headline)) {
                        TextField("Enter amount", text: $amount)
                            .decimalInput($amount)
                            .accessibilityIdentifier("\(mode.identifierPrefix)_AmountTextField")
                    }
                    Section(header: Text("Transaction Type").font(.headline)) {
                        Picker("Type", selection: $isIncome) {
                            Text("Income").tag(true)
                            Text("Expense").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .accessibilityIdentifier("\(mode.identifierPrefix)_TypePicker")
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("\(mode.identifierPrefix)_CancelButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { commit() }
                        .accessibilityIdentifier("\(mode.identifierPrefix)_SaveButton")
                        .disabled(!isFormValid)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
        }
    }

    private var isFormValid: Bool {
        guard let amt = Double(amount), amt > 0, !descriptionText.isEmpty else { return false }
        return true
    }

    private func commit() {
        let target: QuickAddTransaction
        switch mode {
        case .add:
            target = QuickAddTransaction()
            modelContext.insert(target)
        case .edit(let tx):
            target = tx
        }

        target.desc = descriptionText
        target.amount = Double(amount) ?? 0.0
        target.isIncome = isIncome

        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to save quick add transaction: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
