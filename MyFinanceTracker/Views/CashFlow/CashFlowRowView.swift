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
                Text(signedAmount.formattedAsCurrency())
                    .font(.headline)
                    .foregroundColor(item.isOwedToMe ? .green : .red)
                    .monospacedDigit()
                    .accessibilityIdentifier("cashFlowAmount")
            }
            .padding(.horizontal, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var signedAmount: Double {
        let magnitude = abs(item.amount)
        return item.isOwedToMe ? magnitude : -magnitude
    }
}
