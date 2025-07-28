import SwiftUI

struct CashFlowRowView: View {
    var item: CashFlowItem
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.name ?? "Unnamed")
                        .font(.headline)
                        .accessibilityIdentifier("cashFlowName")
                    Text(item.isOwedToMe ? "Owed to Me" : "I Owe")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("cashFlowType")
                }
                Spacer()
                Text(formattedAmount())
                    .font(.headline)
                    .foregroundColor(item.isOwedToMe ? .green : .red)
                    .accessibilityIdentifier("cashFlowAmount")
            }
            .padding(.horizontal, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formattedAmount() -> String {
        let amount = abs(item.amount)
        let prefix = item.isOwedToMe ? "$" : "-$"
        return "\(prefix)\(String(format: "%.2f", amount))"
    }
}
