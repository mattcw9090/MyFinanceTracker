import SwiftUI

struct CashFlowRowView: View {
    @ObservedObject var item: CashFlowItem

    var body: some View {
        HStack {
            Text(item.name ?? "No Name")
                .font(.headline)
            Spacer()
            
            Text("$\(String(format: "%.2f", item.amount))")
                .foregroundColor(item.isOwedToMe ? .green : .red)
                .fontWeight(.bold)
                .font(.title3)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
}
