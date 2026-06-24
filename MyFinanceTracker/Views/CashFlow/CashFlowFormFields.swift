import SwiftUI

struct CashFlowFormFields: View {
    @Binding var name: String
    @Binding var amount: String
    @Binding var isOwedToMe: Bool

    var body: some View {
        VStack(spacing: 18) {
            formField(title: "Name", icon: "person", text: $name, keyboardType: .default)
            formField(title: "Amount", icon: "dollarsign.circle", text: $amount, keyboardType: .decimalPad)

            VStack(alignment: .leading, spacing: 8) {
                Text("Cash Flow Type")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Picker("Type", selection: $isOwedToMe) {
                    Label("Owed to Me", systemImage: "arrow.down.circle.fill").tag(true)
                    Label("I Owe", systemImage: "arrow.up.circle.fill").tag(false)
                }
                .pickerStyle(.segmented)
                .tint(FinanceTheme.accent)
                .accessibilityIdentifier("cashFlowTypePicker")
            }
        }
        .financeCard(padding: 18)
    }

    @ViewBuilder
    private func formField(title: String, icon: String, text: Binding<String>, keyboardType: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                TextField("Enter \(title.lowercased())", text: text)
                    .keyboardType(keyboardType)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .financeField()
        }
    }
}
