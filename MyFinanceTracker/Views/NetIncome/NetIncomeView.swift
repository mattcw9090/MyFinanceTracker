import SwiftUI

struct NetIncomeView: View {
    @EnvironmentObject var netIncomeManager: NetIncomeManager

    var body: some View {
        HStack {
            Text("Net Income:")
                .font(.title2)
                .bold()
            Spacer()
            NavigationLink(destination: AdjustNetIncomeView()) {
                Text("$\(String(format: "%.2f", netIncomeManager.netIncome))")
                    .font(.title2)
                    .bold()
                    .foregroundColor(netIncomeManager.netIncome >= 0 ? .green : .red)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
}
