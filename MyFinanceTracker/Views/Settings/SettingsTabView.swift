import SwiftUI
import CoreData

struct SettingsTabView: View {
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
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemBackground)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                List {
                    // Predefined Transactions Section
                    Section(header: SectionHeader(title: "Predefined Transactions") {
                        showingAddPredefinedTransaction = true
                    }
                    .accessibilityIdentifier("AddPredefined_SectionHeader")
                    ) {
                        if predefinedTransactions.isEmpty {
                            EmptyStateView(message: "No predefined transactions. Add some to get started.", systemImage: "tray")
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(daysOfWeek, id: \.self) { day in
                                let transactionsForDay = predefinedTransactions.filter { $0.dayOfWeek == day }
                                if !transactionsForDay.isEmpty {
                                    Text(day)
                                        .font(.system(size: 15))
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .listRowSeparator(.visible)
                                        .listRowInsets(EdgeInsets())
                                        .listRowBackground(Color.clear)

                                    ForEach(transactionsForDay, id: \.id) { transaction in
                                        PredefinedTransactionRow(transaction: transaction)
                                            .onTapGesture {
                                                predefinedTransactionToEdit = transaction
                                            }
                                            .listRowInsets(EdgeInsets())
                                            .listRowSeparator(.visible)
                                            .listRowBackground(Color.clear)
                                    }
                                    .onDelete { offsets in
                                        deletePredefinedTransaction(offsets, from: transactionsForDay)
                                    }
                                }
                            }
                        }
                    }

                    // Quick Add Transactions Section
                    Section(header: SectionHeader(title: "Quick Add Transactions") {
                        showingAddQuickAddTransaction = true
                    }
                    .accessibilityIdentifier("AddQuickAdd_SectionHeader")
                    ) {
                        if quickAddTransactions.isEmpty {
                            EmptyStateView(message: "No quick add transactions. Add some to get started.", systemImage: "plus.circle")
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } else {
                            let incomeQuickAddTransactions = quickAddTransactions.filter { $0.isIncome }
                            let expenseQuickAddTransactions = quickAddTransactions.filter { !$0.isIncome }

                            if !incomeQuickAddTransactions.isEmpty {
                                Text("Income")
                                    .font(.system(size: 15))
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .listRowSeparator(.visible)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)

                                ForEach(incomeQuickAddTransactions, id: \.id) { transaction in
                                    QuickAddTransactionRow(transaction: transaction)
                                        .onTapGesture {
                                            quickAddTransactionToEdit = transaction
                                        }
                                        .listRowInsets(EdgeInsets())
                                        .listRowSeparator(.visible)
                                        .listRowBackground(Color.clear)
                                }
                                .onDelete { offsets in
                                    deleteQuickAddTransaction(offsets: offsets, from: incomeQuickAddTransactions)
                                }
                            }

                            if !expenseQuickAddTransactions.isEmpty {
                                Text("Expense")
                                    .font(.system(size: 15))
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .listRowSeparator(.visible)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)

                                ForEach(expenseQuickAddTransactions, id: \.id) { transaction in
                                    QuickAddTransactionRow(transaction: transaction)
                                        .onTapGesture {
                                            quickAddTransactionToEdit = transaction
                                        }
                                        .listRowInsets(EdgeInsets())
                                        .listRowSeparator(.visible)
                                        .listRowBackground(Color.clear)
                                }
                                .onDelete { offsets in
                                    deleteQuickAddTransaction(offsets: offsets, from: expenseQuickAddTransactions)
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarItems(trailing: EditButton())
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

    // MARK: - Predefined Transaction Row
    struct PredefinedTransactionRow: View {
        let transaction: PredefinedTransaction

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

                HStack(spacing: 16) {
                    Image(systemName: transaction.isIncome ? "arrow.up.circle" : "arrow.down.circle")
                        .foregroundColor(transaction.isIncome ? .green : .red)
                        .imageScale(.medium)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(transaction.desc ?? "No Description")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text(transaction.isIncome ? "Income" : "Expense")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(formattedAmount(transaction: transaction))
                        .foregroundColor(transaction.isIncome ? .green : .red)
                        .fontWeight(.bold)
                        .font(.body)
                }
                .padding()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }

        private func formattedAmount(transaction: PredefinedTransaction) -> String {
            let amount = abs(transaction.amount)
            let prefix = transaction.isIncome ? "$" : "-$"
            return "\(prefix)\(String(format: "%.2f", amount))"
        }
    }

    // MARK: - Quick Add Transaction Row
    struct QuickAddTransactionRow: View {
        let transaction: QuickAddTransaction

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

                HStack(spacing: 16) {
                    Image(systemName: transaction.isIncome ? "arrow.up.circle" : "arrow.down.circle")
                        .foregroundColor(transaction.isIncome ? .green : .red)
                        .imageScale(.medium)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(transaction.desc ?? "No Description")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text(transaction.isIncome ? "Income" : "Expense")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(formattedAmount(transaction: transaction))
                        .foregroundColor(transaction.isIncome ? .green : .red)
                        .fontWeight(.bold)
                        .font(.body)
                }
                .padding()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }

        private func formattedAmount(transaction: QuickAddTransaction) -> String {
            let amount = abs(transaction.amount)
            let prefix = transaction.isIncome ? "$" : "-$"
            return "\(prefix)\(String(format: "%.2f", amount))"
        }
    }

    // MARK: - Helper Functions

    private func deletePredefinedTransaction(_ offsets: IndexSet, from transactionsForDay: [PredefinedTransaction]) {
        withAnimation {
            offsets.map { transactionsForDay[$0] }.forEach(viewContext.delete)
            saveContext()
        }
    }

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
