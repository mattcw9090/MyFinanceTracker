import SwiftUI
import CoreData

struct AddTransactionView: View {
    let isIncome: Bool
    @Binding var selectedDay: String

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var descriptionText = ""
    @State private var amount = ""

    let days = Weekday.allNames

    @EnvironmentObject var netIncomeManager: NetIncomeManager

    @State private var showAlert = false
    @State private var alertMessage = ""

    @FetchRequest private var quickAddTransactions: FetchedResults<QuickAddTransaction>

    init(isIncome: Bool, selectedDay: Binding<String>) {
        self.isIncome = isIncome
        _selectedDay = selectedDay

        let predicate = NSPredicate(format: "isIncome == %@", NSNumber(value: isIncome))
        let sortDescriptors = [NSSortDescriptor(keyPath: \QuickAddTransaction.desc, ascending: true)]
        _quickAddTransactions = FetchRequest(
            entity: QuickAddTransaction.entity(),
            sortDescriptors: sortDescriptors,
            predicate: predicate
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemBackground)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 25) {
                        // Day Picker Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Day of the Week")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Picker("Select Day", selection: $selectedDay) {
                                ForEach(days, id: \.self) { day in
                                    Text(day)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(height: 150)
                            .accessibilityIdentifier("AddTransaction_DayPicker")
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.systemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .padding(.horizontal)

                        // Manual Entry Card
                        VStack(alignment: .leading, spacing: 18) {
                            // Description Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("DESCRIPTION")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                TextField("Enter Description", text: $descriptionText)
                                    .padding(12)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(8)
                                    .disableAutocorrection(true)
                                    .accessibilityIdentifier("descriptionField")
                            }

                            // Amount Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("AMOUNT")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                TextField("Enter Amount", text: $amount)
                                    .decimalInput($amount)
                                    .padding(12)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(8)
                                    .accessibilityIdentifier("amountField")
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.systemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .padding(.horizontal)

                        // Quick Add Card
                        if !quickAddTransactions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Quick Add")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                VStack(spacing: 12) {
                                    ForEach(quickAddTransactions, id: \.id) { transaction in
                                        Button(action: {
                                            applyQuickAddTransaction(transaction)
                                        }) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(transaction.desc ?? "")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.primary)
                                                Text(transaction.amount.formattedAsCurrency())
                                                    .font(.caption)
                                                    .foregroundColor(transaction.isIncome ? .green : .red)
                                            }
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(transaction.isIncome ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                            )
                                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .accessibilityIdentifier("quickAdd_\(transaction.desc ?? "no_desc")")
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            )
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(.vertical)
                }
                .navigationTitle(isIncome ? "Add Income" : "Add Expense")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .fontWeight(.semibold)
                            .accessibilityIdentifier("cancelButton")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            addTransaction()
                        } label: {
                            Text("Save")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isFormValid() ? Color.accentColor : Color.gray.opacity(0.5))
                                )
                        }
                        .disabled(!isFormValid())
                        .accessibilityIdentifier("saveButton")
                    }
                }
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Error"),
                          message: Text(alertMessage),
                          dismissButton: .default(Text("OK")))
                }
            }
        }
    }

    private func isFormValid() -> Bool {
        guard let amt = Double(amount), amt > 0, !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        return true
    }

    private func addTransaction() {
        createTransaction(
            amount: Double(amount) ?? 0.0,
            desc: descriptionText,
            isIncome: isIncome
        )
    }

    private func applyQuickAddTransaction(_ template: QuickAddTransaction) {
        createTransaction(
            amount: template.amount,
            desc: template.desc ?? "",
            isIncome: template.isIncome
        )
    }

    private func createTransaction(amount: Double, desc: String, isIncome: Bool) {
        let newTransaction = Transaction(context: viewContext)
        newTransaction.id = UUID()
        newTransaction.amount = amount
        newTransaction.desc = desc
        newTransaction.dayOfWeek = selectedDay
        newTransaction.isCompleted = false
        newTransaction.isIncome = isIncome

        netIncomeManager.adjustNetIncome(by: amount, isIncome: isIncome, isDeletion: false)

        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to add transaction: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
