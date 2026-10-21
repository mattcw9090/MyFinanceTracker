import SwiftUI

struct CashFlowFormFields: View {
    @Binding var name: String
    @Binding var amount: String
    @Binding var isOwedToMe: Bool

    var body: some View {
        VStack(spacing: 18) {
            formField(title: "Name", icon: "person", text: $name, keyboardType: .default)
            amountField

            VStack(alignment: .leading, spacing: 8) {
                Text("Cash Flow Type")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Picker("Type", selection: $isOwedToMe) {
                    Label("Owed to Me", systemImage: FinanceMark.income).tag(true)
                    Label("I Owe", systemImage: FinanceMark.expense).tag(false)
                }
                .pickerStyle(.segmented)
                .tint(FinanceTheme.accent)
                .accessibilityIdentifier("cashFlowTypePicker")
            }
        }
        .financeCard(padding: 18)
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount")
                .font(.headline)
                .foregroundStyle(.primary)
            CurrencyAmountField(amount: $amount, identifier: "cashFlowAmountField")
                .financeField()
        }
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
