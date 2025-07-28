import SwiftUI

struct NetIncomeView: View {
    @EnvironmentObject var netIncomeManager: NetIncomeManager

    var body: some View {
        HStack {
            Text("Net Income:")
                .font(.title2)
                .bold()
                .accessibilityIdentifier("netIncomeLabel")
            Spacer()
            NavigationLink(destination: AdjustNetIncomeView()) {
                Text(formattedNetIncome())
                    .font(.title2)
                    .bold()
                    .foregroundColor(netIncomeManager.netIncome >= 0 ? .green : .red)
                    .accessibilityIdentifier("netIncomeValue")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding(.horizontal)
        .padding(.bottom, 16)
    }

    /// Formats the net income value, ensuring no double negative.
    private func formattedNetIncome() -> String {
        let amount = abs(netIncomeManager.netIncome)
        let prefix = netIncomeManager.netIncome >= 0 ? "$" : "-$"
        return "\(prefix)\(String(format: "%.2f", amount))"
    }
}
