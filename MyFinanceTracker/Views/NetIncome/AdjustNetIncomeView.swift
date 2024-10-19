import SwiftUI

struct AdjustNetIncomeView: View {
    @EnvironmentObject var netIncomeManager: NetIncomeManager
    @Environment(\.dismiss) var dismiss

    @State private var amount: String = ""
    @State private var isAddition: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    // Focus state to control the keyboard
    @FocusState private var isAmountFieldFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Adjust Net Income")
                .font(.largeTitle)
                .bold()
                .padding(.top, 40)
            
            // Toggle Between Add and Subtract
            Picker("Operation", selection: $isAddition) {
                Text("Add").tag(true)
                Text("Subtract").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            // Amount Input Field
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
                    .focused($isAmountFieldFocused) // Bind to the focus state
            }
            .padding(.horizontal)

            // Action Buttons
            HStack(spacing: 20) {
                Button(action: {
                    adjustNetIncome()
                }) {
                    Text("Confirm")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }

                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(8)
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
            // Automatically focus the text field when the view appears
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
