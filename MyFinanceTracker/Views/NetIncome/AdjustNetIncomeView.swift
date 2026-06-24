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
        VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.2.square")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(FinanceTheme.accent)
                    Text("Fine-tune your balance")
                        .font(.title3.weight(.semibold))
                    Text("Use this for corrections that aren’t transactions.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                Picker("Operation", selection: $isAddition) {
                    Text("Add").tag(true)
                    Text("Subtract").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .tint(FinanceTheme.accent)
                .accessibilityIdentifier("operationPicker")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.headline)

                    TextField("Enter Amount", text: $amount)
                        .keyboardType(.decimalPad)
                        .financeField()
                        .accessibilityIdentifier("adjustAmountField")
                        .focused($isAmountFieldFocused)
                }
                .financeCard(padding: 18)

                VStack(spacing: 10) {
                    Button(action: { adjustNetIncome() }) {
                        Text("Confirm")
                    }
                    .buttonStyle(FinancePrimaryButtonStyle())
                    .accessibilityIdentifier("confirmButton")

                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .accessibilityIdentifier("adjustCancelButton")
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .financeBackground()
            .navigationTitle("Adjust Balance")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Invalid Input"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
            .onAppear {
                isAmountFieldFocused = true
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
