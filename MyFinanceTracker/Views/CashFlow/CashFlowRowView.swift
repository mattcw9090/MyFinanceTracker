import SwiftUI

struct CashFlowRowView: View {
    @ObservedObject var item: CashFlowItem

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: item.isOwedToMe ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundColor(item.isOwedToMe ? .green : .red)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name ?? "No Name")
                    .font(.headline)
                Text(item.isOwedToMe ? "Owed to me" : "I owe")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("$\(String(format: "%.2f", item.amount))")
                .foregroundColor(.primary)
                .fontWeight(.bold)
                .font(.title3)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}
