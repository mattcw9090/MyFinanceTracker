import SwiftUI

struct AdjustNetIncomeView: View {
    @EnvironmentObject var netIncomeManager: NetIncomeManager
    @Environment(\.dismiss) var dismiss

    @State private var amount: String = ""
    @State private var isAddition: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    @FocusState private var isAmountFieldFocused: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemBackground)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Adjust Net Income")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 40)
                    .foregroundColor(.primary)

                // Operation Picker
                Picker("Operation", selection: $isAddition) {
                    Text("Add").tag(true)
                    Text("Subtract").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .tint(.accentColor)

                VStack(alignment: .leading, spacing: 8) {
                    Text("AMOUNT")
                        .font(.headline)
                        .foregroundColor(.primary)

                    TextField("Enter Amount", text: $amount)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                        .focused($isAmountFieldFocused)
                }
                .padding(.horizontal)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
                )
                .padding(.horizontal)

                HStack(spacing: 20) {
                    Button(action: { adjustNetIncome() }) {
                        Text("Confirm")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }

                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Invalid Input"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
            .onAppear {
                isAmountFieldFocused = true
            }
        }
    }

    private func adjustNetIncome() {
        guard let value = Double(amount), value > 0 else {
            alertMessage = "Please enter a valid positive number."
            showAlert = true
            return
        }

        if isAddition {
            netIncomeManager.netIncome += value
        } else {
            netIncomeManager.netIncome -= value
        }

        dismiss()
    }
}
