import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: PredefinedTransaction.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PredefinedTransaction.dayOfWeek, ascending: true)]
    )
    private var predefinedTransactions: FetchedResults<PredefinedTransaction>

    @FetchRequest(
        entity: QuickAddTransaction.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \QuickAddTransaction.desc, ascending: true)]
    )
    private var quickAddTransactions: FetchedResults<QuickAddTransaction>

    @State private var showingAddPredefinedTransaction = false
    @State private var predefinedTransactionToEdit: PredefinedTransaction?

    @State private var showingAddQuickAddTransaction = false
    @State private var quickAddTransactionToEdit: QuickAddTransaction?

    let daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        NavigationView {
            List {
                // Predefined Transactions Section
                Section(header: SectionHeader(title: "Predefined Transactions", action: {
                    showingAddPredefinedTransaction = true
                })) {
                    if predefinedTransactions.isEmpty {
                        EmptyStateView(message: "No predefined transactions. Add some to get started.", systemImage: "tray")
                    } else {
                        ForEach(daysOfWeek, id: \.self) { day in
                            let transactionsForDay = predefinedTransactions.filter { $0.dayOfWeek == day }
                            if !transactionsForDay.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(day)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .padding(.vertical, 4)
                                        .foregroundColor(.primary)
                                    
                                    ForEach(transactionsForDay, id: \.id) { transaction in
                                        PredefinedTransactionCard(transaction: transaction)
                                            .onTapGesture {
                                                predefinedTransactionToEdit = transaction
                                            }
                                    }
                                    .onDelete { offsets in
                                        deletePredefinedTransaction(offsets, from: transactionsForDay)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                // Quick Add Transactions Section
                Section(header: SectionHeader(title: "Quick Add Transactions", action: {
                    showingAddQuickAddTransaction = true
                })) {
                    if quickAddTransactions.isEmpty {
                        EmptyStateView(message: "No quick add transactions. Add some to get started.", systemImage: "plus.circle")
                    } else {
                        // Categorize Quick Add Transactions into Income and Expense
                        let incomeQuickAddTransactions = quickAddTransactions.filter { $0.isIncome }
                        let expenseQuickAddTransactions = quickAddTransactions.filter { !$0.isIncome }

                        if !incomeQuickAddTransactions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Income")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .padding(.vertical, 4)
                                    .foregroundColor(.green)
                                
                                ForEach(incomeQuickAddTransactions, id: \.id) { transaction in
                                    QuickAddTransactionCard(transaction: transaction)
                                        .onTapGesture {
                                            quickAddTransactionToEdit = transaction
                                        }
                                }
                                .onDelete { offsets in
                                    deleteQuickAddTransaction(offsets: offsets, from: incomeQuickAddTransactions)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        if !expenseQuickAddTransactions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Expense")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .padding(.vertical, 4)
                                    .foregroundColor(.red)
                                
                                ForEach(expenseQuickAddTransactions, id: \.id) { transaction in
                                    QuickAddTransactionCard(transaction: transaction)
                                        .onTapGesture {
                                            quickAddTransactionToEdit = transaction
                                        }
                                }
                                .onDelete { offsets in
                                    deleteQuickAddTransaction(offsets: offsets, from: expenseQuickAddTransactions)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarItems(trailing: EditButton())
            // Sheets for Predefined Transactions
            .sheet(isPresented: $showingAddPredefinedTransaction) {
                NavigationView {
                    AddPredefinedTransactionView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .sheet(item: $predefinedTransactionToEdit) { transaction in
                NavigationView {
                    EditPredefinedTransactionView(transaction: transaction)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            // Sheets for Quick Add Transactions
            .sheet(isPresented: $showingAddQuickAddTransaction) {
                NavigationView {
                    AddQuickAddTransactionView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .sheet(item: $quickAddTransactionToEdit) { transaction in
                NavigationView {
                    EditQuickAddTransactionView(transaction: transaction)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
        }
    }

    // MARK: - Section Header View
    struct SectionHeader: View {
        let title: String
        let action: () -> Void

        var body: some View {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: action) {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                        .foregroundColor(.purple)
                }
                .buttonStyle(BorderlessButtonStyle())
                .accessibilityLabel("Add \(title)")
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty State View
    struct EmptyStateView: View {
        let message: String
        let systemImage: String

        var body: some View {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.gray)
                    .padding(.trailing, 8)
                Text(message)
                    .foregroundColor(.gray)
                    .italic()
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Predefined Transaction Card View
    struct PredefinedTransactionCard: View {
        let transaction: PredefinedTransaction

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(transaction.desc ?? "No Description")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    HStack {
                        Image(systemName: transaction.isIncome ? "arrow.up.circle" : "arrow.down.circle")
                            .foregroundColor(transaction.isIncome ? .green : .red)
                            .imageScale(.small)
                        Text(transaction.isIncome ? "Income" : "Expense")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(formattedAmount(transaction: transaction))
                    .foregroundColor(transaction.isIncome ? .green : .red)
                    .fontWeight(.bold)
                    .frame(minWidth: 80, alignment: .trailing)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.vertical, 4)
        }

        // Helper to format amount
        private func formattedAmount(transaction: PredefinedTransaction) -> String {
            let amount = transaction.isIncome ? transaction.amount : -transaction.amount
            return String(format: "$%.2f", amount)
        }
    }

    // MARK: - Quick Add Transaction Card View
    struct QuickAddTransactionCard: View {
        let transaction: QuickAddTransaction

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(transaction.desc ?? "No Description")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    HStack {
                        Image(systemName: transaction.isIncome ? "arrow.up.circle" : "arrow.down.circle")
                            .foregroundColor(transaction.isIncome ? .green : .red)
                            .imageScale(.small)
                        Text(transaction.isIncome ? "Income" : "Expense")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(formattedAmount(transaction: transaction))
                    .foregroundColor(transaction.isIncome ? .green : .red)
                    .fontWeight(.bold)
                    .frame(minWidth: 80, alignment: .trailing)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.vertical, 4)
        }

        // Helper to format amount
        private func formattedAmount(transaction: QuickAddTransaction) -> String {
            let amount = transaction.isIncome ? transaction.amount : -transaction.amount
            return String(format: "$%.2f", amount)
        }
    }

    // MARK: - Helper Functions

    // Helper function to format amount
    private func formattedAmount(transaction: PredefinedTransaction) -> String {
        let amount = transaction.isIncome ? transaction.amount : -transaction.amount
        return String(format: "$%.2f", amount)
    }

    private func formattedAmount(transaction: QuickAddTransaction) -> String {
        let amount = transaction.isIncome ? transaction.amount : -transaction.amount
        return String(format: "$%.2f", amount)
    }

    // Functions for Predefined Transactions
    private func deletePredefinedTransaction(_ offsets: IndexSet, from transactionsForDay: [PredefinedTransaction]) {
        withAnimation {
            offsets.map { transactionsForDay[$0] }.forEach(viewContext.delete)
            saveContext()
        }
    }

    // Functions for Quick Add Transactions
    private func deleteQuickAddTransaction(offsets: IndexSet, from transactionsSubset: [QuickAddTransaction]) {
        withAnimation {
            offsets.map { transactionsSubset[$0] }.forEach(viewContext.delete)
            saveContext()
        }
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error.localizedDescription)")
        }
    }
}
