import SwiftUI

struct CashFlowFormFields: View {
    @Binding var name: String
    @Binding var amount: String
    @Binding var isOwedToMe: Bool

    var body: some View {
        VStack(spacing: 20) {
            formField(title: "Name", icon: "person", text: $name, keyboardType: .default)
            formField(title: "Amount", icon: "dollarsign.circle", text: $amount, keyboardType: .decimalPad)

            // Cash Flow Type Picker
            VStack(alignment: .leading, spacing: 5) {
                Text("Cash Flow Type")
                    .font(.headline)
                    .foregroundColor(.primary)
                Picker("Type", selection: $isOwedToMe) {
                    Label("Owed to Me", systemImage: "arrow.down.circle.fill").tag(true)
                    Label("I Owe", systemImage: "arrow.up.circle.fill").tag(false)
                }
                .pickerStyle(.segmented)
                .tint(.accentColor)
                .accessibilityIdentifier("cashFlowTypePicker")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
        )
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func formField(title: String, icon: String, text: Binding<String>, keyboardType: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                TextField("Enter \(title.lowercased())", text: text)
                    .keyboardType(keyboardType)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }
}
