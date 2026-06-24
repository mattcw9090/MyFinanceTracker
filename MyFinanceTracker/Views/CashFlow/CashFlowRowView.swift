import SwiftUI

struct CashFlowRowView: View {
    @ObservedObject var item: CashFlowItem
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                if item.isSettled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.large)
                }

                VStack(alignment: .leading) {
                    Text(item.name ?? "Unnamed")
                        .font(.headline)
                        .strikethrough(item.isSettled)
                        .foregroundStyle(item.isSettled ? .secondary : .primary)
                        .accessibilityIdentifier("cashFlowName")
                    Text(item.isOwedToMe ? "Owed to Me" : "I Owe")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("cashFlowType")
                }
                Spacer()
                Text(signedAmount.formattedAsCurrency())
                    .font(.headline)
                    .foregroundColor(amountColor)
                    .strikethrough(item.isSettled)
                    .monospacedDigit()
                    .accessibilityIdentifier("cashFlowAmount")
            }
            .padding(.horizontal, 8)
            .opacity(item.isSettled ? 0.55 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var signedAmount: Double {
        let magnitude = abs(item.amount)
        return item.isOwedToMe ? magnitude : -magnitude
    }

    private var amountColor: Color {
        if item.isSettled { return .secondary }
        return item.isOwedToMe ? .green : .red
    }
}
