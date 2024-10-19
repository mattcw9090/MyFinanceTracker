import SwiftUI

struct CashFlowFormFields: View {
    @Binding var name: String
    @Binding var amount: String
    @Binding var isOwedToMe: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Name Field
            VStack(alignment: .leading, spacing: 5) {
                Text("Name")
                    .font(.headline)
                    .foregroundColor(.primary)
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.secondary)
                    TextField("Enter name", text: $name)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }

            // Amount Field
            VStack(alignment: .leading, spacing: 5) {
                Text("Amount")
                    .font(.headline)
                    .foregroundColor(.primary)
                HStack {
                    Image(systemName: "dollarsign.circle")
                        .foregroundColor(.secondary)
                    TextField("Enter amount", text: $amount)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }

            // Cash Flow Type Picker
            VStack(alignment: .leading, spacing: 5) {
                Text("Cash Flow Type")
                    .font(.headline)
                    .foregroundColor(.primary)
                Picker("Type", selection: $isOwedToMe) {
                    Label("Owed to Me", systemImage: "arrow.down.circle.fill").tag(true)
                    Label("I Owe", systemImage: "arrow.up.circle.fill").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .tint(.accentColor)
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
}
