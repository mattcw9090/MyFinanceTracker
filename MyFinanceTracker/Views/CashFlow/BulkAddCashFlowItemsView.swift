import SwiftUI
import SwiftData

struct BulkAddCashFlowItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var amount = ""
    @State private var isOwedToMe: Bool
    @State private var names: [String] = [""]
    @State private var showAlert = false
    @State private var alertMessage = ""

    init(isDefaultOwedToMe: Bool = true) {
        _isOwedToMe = State(initialValue: isDefaultOwedToMe)
    }

    private var trimmedNames: [String] {
        names
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var isFormValid: Bool {
        guard let amt = Double(amount), amt > 0 else { return false }
        return !trimmedNames.isEmpty
    }

    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    sharedDetailsCard
                        .padding(.horizontal)
                        .padding(.top, 12)

                    namesCard
                        .padding(.horizontal)

                    Button(action: saveAll) {
                        Text(saveButtonTitle)
                    }
                    .buttonStyle(FinancePrimaryButtonStyle())
                    .disabled(!isFormValid)
                    .opacity(isFormValid ? 1 : 0.45)
                    .padding(.horizontal)
                    .accessibilityIdentifier("BulkAdd_SaveButton")
                }
                .padding(.bottom, 50)
        }
        .financeBackground()
        .navigationTitle("Add Multiple")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .accessibilityIdentifier("BulkAdd_CancelButton")
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

    private var saveButtonTitle: String {
        let count = trimmedNames.count
        if count <= 1 { return "Save" }
        return "Save \(count) Items"
    }

    private var sharedDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Cash Flow Type")
                    .font(.headline)
                    .foregroundColor(.primary)
                Picker("Type", selection: $isOwedToMe) {
                    Label("Owed to Me", systemImage: "arrow.down.circle.fill").tag(true)
                    Label("I Owe", systemImage: "arrow.up.circle.fill").tag(false)
                }
                .pickerStyle(.segmented)
                .tint(FinanceTheme.accent)
                .accessibilityIdentifier("BulkAdd_TypePicker")
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Amount (per person)")
                    .font(.headline)
                    .foregroundColor(.primary)
                HStack {
                    Image(systemName: "dollarsign.circle")
                        .foregroundColor(.secondary)
                    TextField("Enter amount", text: $amount)
                        .decimalInput($amount)
                        .textFieldStyle(PlainTextFieldStyle())
                        .accessibilityIdentifier("BulkAdd_AmountField")
                }
                .financeField()
            }
        }
        .financeCard(padding: 18)
    }

    private var namesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Names")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: addName) {
                    Label("Add", systemImage: "plus.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }
                .accessibilityIdentifier("BulkAdd_AddNameButton")
            }

            ForEach(names.indices, id: \.self) { index in
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.secondary)
                    TextField("Name \(index + 1)", text: $names[index])
                        .textFieldStyle(PlainTextFieldStyle())
                        .accessibilityIdentifier("BulkAdd_NameField_\(index)")

                    if names.count > 1 {
                        Button {
                            removeName(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(FinanceTheme.expense)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .accessibilityIdentifier("BulkAdd_RemoveNameButton_\(index)")
                    }
                }
                .financeField()
            }
        }
        .financeCard(padding: 18)
    }

    private func addName() {
        names.append("")
    }

    private func removeName(at index: Int) {
        guard names.indices.contains(index) else { return }
        names.remove(at: index)
    }

    private func saveAll() {
        let share = Double(amount) ?? 0
        let toCreate = trimmedNames
        guard share > 0, !toCreate.isEmpty else { return }

        for name in toCreate {
            modelContext.insert(CashFlowItem(
                name: name,
                amount: share,
                isOwedToMe: isOwedToMe
            ))
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to save items: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
