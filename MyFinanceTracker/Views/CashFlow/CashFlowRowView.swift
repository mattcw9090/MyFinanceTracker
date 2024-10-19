import SwiftUI

struct CashFlowRowView: View {
    @ObservedObject var item: CashFlowItem

    var body: some View {
        HStack {
            Image(systemName: item.isOwedToMe ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundColor(item.isOwedToMe ? .green : .red)
                .font(.title2)
                .padding(.trailing, 5)

            VStack(alignment: .leading, spacing: 2) {
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
                .fill(Color(UIColor.systemGray6))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
}
