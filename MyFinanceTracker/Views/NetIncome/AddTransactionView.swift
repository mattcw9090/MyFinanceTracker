import SwiftUI
import CoreData

struct AddTransactionView: View {
    let isIncome: Bool
    let defaultDay: String

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var descriptionText = ""
    @State private var amount = ""
    @State private var selectedDay: String

    let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    @EnvironmentObject var netIncomeManager: NetIncomeManager

    @State private var showAlert = false
    @State private var alertMessage = ""

    @FetchRequest private var quickAddTransactions: FetchedResults<QuickAddTransaction>

    init(isIncome: Bool, defaultDay: String) {
        self.isIncome = isIncome
        self.defaultDay = defaultDay
        _selectedDay = State(initialValue: defaultDay)

        let predicate = NSPredicate(format: "isIncome == %@", NSNumber(value: isIncome))
        let sortDescriptors = [NSSortDescriptor(keyPath: \QuickAddTransaction.desc, ascending: true)]
        _quickAddTransactions = FetchRequest(
            entity: QuickAddTransaction.entity(),
            sortDescriptors: sortDescriptors,
            predicate: predicate
        )
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) { // Increased spacing for better separation
                    // Day Picker Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Day of the Week")
                            .font(.headline)
                            .foregroundColor(.primary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(days, id: \.self) { day in
                                    Button(action: {
                                        selectedDay = day
                                    }) {
                                        Text(day)
                                            .font(.subheadline)
                                            .fontWeight(selectedDay == day ? .semibold : .regular)
                                            .foregroundColor(selectedDay == day ? .white : .primary)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 16)
                                            .background(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(selectedDay == day ? Color.purple : Color(UIColor.secondarySystemBackground))
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                    // **Manual Entry Section** (Header Removed, Labels Enlarged, Icons Removed)
                    VStack(alignment: .leading, spacing: 18) {
                        // DESCRIPTION Label and Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DESCRIPTION")
                                .font(.headline) // Increased font size
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            TextField("Enter Description", text: $descriptionText)
                                .padding(12)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                .disableAutocorrection(true) // Optional: Disable autocorrection for description
                        }

                        // AMOUNT Label and Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AMOUNT")
                                .font(.headline) // Increased font size
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            TextField("Enter Amount", text: $amount)
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                .onReceive(amount.publisher.collect()) { newValue in
                                    let filtered = newValue.filter { "0123456789.".contains($0) }
                                    if filtered != newValue {
                                        amount = String(filtered.prefix(10))
                                    }
                                }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                    // **Quick Add Transactions Section** (Swapped to appear after Manual Entry)
                    if !quickAddTransactions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Add")
                                .font(.headline)
                                .foregroundColor(.primary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 20) {
                                    ForEach(quickAddTransactions, id: \.id) { transaction in
                                        Button(action: {
                                            applyQuickAddTransaction(transaction)
                                        }) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(transaction.desc ?? "")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.primary)
                                                Text("$\(String(format: "%.2f", transaction.amount))")
                                                    .font(.caption)
                                                    .foregroundColor(transaction.isIncome ? .green : .red)
                                            }
                                            .padding()
                                            .frame(width: 140, height: 90)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(transaction.isIncome ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                            )
                                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }

                    Spacer()
                }
                .padding(.vertical)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemBackground)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
            )
            .navigationBarTitle(isIncome ? "Add Income" : "Add Expense", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                },
                trailing: Button(action: {
                    addTransaction()
                }) {
                    Text("Save")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isFormValid() ? Color.purple : Color.gray.opacity(0.5))
                        )
                }
                .disabled(!isFormValid())
            )
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func isFormValid() -> Bool {
        guard let amt = Double(amount), amt > 0, !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        return true
    }

    private func addTransaction() {
        let newTransaction = Transaction(context: viewContext)
        newTransaction.id = UUID()
        newTransaction.amount = Double(amount) ?? 0.0
        newTransaction.desc = descriptionText
        newTransaction.dayOfWeek = selectedDay
        newTransaction.isCompleted = false
        newTransaction.isIncome = isIncome

        netIncomeManager.adjustNetIncome(by: newTransaction.amount, isIncome: isIncome, isDeletion: false)

        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to add transaction: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func applyQuickAddTransaction(_ transaction: QuickAddTransaction) {
        let newTransaction = Transaction(context: viewContext)
        newTransaction.id = UUID()
        newTransaction.amount = transaction.amount
        newTransaction.desc = transaction.desc
        newTransaction.dayOfWeek = selectedDay
        newTransaction.isCompleted = false
        newTransaction.isIncome = transaction.isIncome

        netIncomeManager.adjustNetIncome(by: transaction.amount, isIncome: transaction.isIncome, isDeletion: false)

        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to add transaction: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
