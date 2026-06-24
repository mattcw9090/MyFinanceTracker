import SwiftUI
import SwiftData

struct SettingsTabView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PredefinedTransaction.dayOfWeek) private var predefinedTransactions: [PredefinedTransaction]
    @Query(sort: \QuickAddTransaction.desc) private var quickAddTransactions: [QuickAddTransaction]

    @State private var showingAddPredefinedTransaction = false
    @State private var predefinedTransactionToEdit: PredefinedTransaction?
    @State private var predefinedTransactionToDuplicate: PredefinedTransaction?
    @State private var showingAddQuickAddTransaction = false
    @State private var quickAddTransactionToEdit: QuickAddTransaction?

    let daysOfWeek = Weekday.allNames

    var body: some View {
        NavigationStack {
            List {
                    Section {
                        HStack(spacing: 14) {
                            Image(systemName: "wand.and.stars")
                                .font(.title3)
                                .foregroundStyle(FinanceTheme.accent)
                                .frame(width: 42, height: 42)
                                .background(FinanceTheme.accent.opacity(0.1), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Make each week effortless")
                                    .font(.headline)
                                Text("Build reusable transactions and quick shortcuts.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    predefinedGroup
                    quickAddGroup
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .financeBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddPredefinedTransaction = true
                        } label: {
                            Label("Add Predefined Transaction", systemImage: "calendar.badge.plus")
                        }
                        .accessibilityIdentifier("AddPredefined_SectionHeader")

                        Button {
                            showingAddQuickAddTransaction = true
                        } label: {
                            Label("Add Quick Add Transaction", systemImage: "bolt.fill")
                        }
                        .accessibilityIdentifier("AddQuickAdd_SectionHeader")
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(FinanceTheme.accent)
                    }
                    .accessibilityIdentifier("Settings_AddMenu")
                }
            }
            .sheet(isPresented: $showingAddPredefinedTransaction) {
                PredefinedTransactionFormView(mode: .add)
            }
            .sheet(item: $predefinedTransactionToEdit) { transaction in
                PredefinedTransactionFormView(mode: .edit(transaction))
            }
            .sheet(item: $predefinedTransactionToDuplicate) { transaction in
                DuplicatePredefinedTransactionView(source: transaction)
            }
            .sheet(isPresented: $showingAddQuickAddTransaction) {
                QuickAddTransactionFormView(mode: .add)
            }
            .sheet(item: $quickAddTransactionToEdit) { transaction in
                QuickAddTransactionFormView(mode: .edit(transaction))
            }
        }
    }

    // MARK: - Predefined Group

    @ViewBuilder
    private var predefinedGroup: some View {
        Section {
            if predefinedTransactions.isEmpty {
                EmptyStateView(
                    message: "No predefined transactions. Add some to get started.",
                    imageName: "tray"
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(daysOfWeek, id: \.self) { day in
                    let items = predefinedTransactions.filter { $0.dayOfWeek == day }
                    if !items.isEmpty {
                        SectionSubHeader(text: day)

                        ForEach(items, id: \.id) { transaction in
                            PredefinedTransactionRow(transaction: transaction)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    predefinedTransactionToEdit = transaction
                                }
                                .contextMenu {
                                    Button {
                                        predefinedTransactionToEdit = transaction
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button {
                                        predefinedTransactionToDuplicate = transaction
                                    } label: {
                                        Label("Duplicate to…", systemImage: "doc.on.doc")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        predefinedTransactionToDuplicate = transaction
                                    } label: {
                                        Label("Duplicate", systemImage: "doc.on.doc")
                                    }
                                    .tint(.blue)
                                }
                        }
                        .onDelete { offsets in
                            deletePredefinedTransaction(offsets, from: items)
                        }
                    }
                }
            }
        } header: {
            Text("Predefined Transactions")
        }
    }

    // MARK: - Quick Add Group

    @ViewBuilder
    private var quickAddGroup: some View {
        Section {
            if quickAddTransactions.isEmpty {
                EmptyStateView(
                    message: "No quick add transactions. Add some to get started.",
                    imageName: "plus.circle"
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                let income = quickAddTransactions.filter { $0.isIncome }
                let expense = quickAddTransactions.filter { !$0.isIncome }

                if !income.isEmpty {
                    SectionSubHeader(text: "Income", tint: FinanceTheme.income)

                    ForEach(income, id: \.id) { transaction in
                        QuickAddTransactionRow(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                quickAddTransactionToEdit = transaction
                            }
                    }
                    .onDelete { offsets in
                        deleteQuickAddTransaction(offsets: offsets, from: income)
                    }
                }

                if !expense.isEmpty {
                    SectionSubHeader(text: "Expense", tint: FinanceTheme.expense)

                    ForEach(expense, id: \.id) { transaction in
                        QuickAddTransactionRow(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                quickAddTransactionToEdit = transaction
                            }
                    }
                    .onDelete { offsets in
                        deleteQuickAddTransaction(offsets: offsets, from: expense)
                    }
                }
            }
        } header: {
            Text("Quick Add Transactions")
        }
    }

    // MARK: - Helpers

    private func deletePredefinedTransaction(_ offsets: IndexSet, from transactionsForDay: [PredefinedTransaction]) {
        withAnimation {
            offsets.map { transactionsForDay[$0] }.forEach(modelContext.delete)
            modelContext.saveOrLog()
        }
    }

    private func deleteQuickAddTransaction(offsets: IndexSet, from transactionsSubset: [QuickAddTransaction]) {
        withAnimation {
            offsets.map { transactionsSubset[$0] }.forEach(modelContext.delete)
            modelContext.saveOrLog()
        }
    }
}

// MARK: - Sub-header row inside a Section

private struct SectionSubHeader: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundColor(tint)
            .padding(.top, 6)
            .padding(.bottom, 2)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

// MARK: - Observed wrappers (pick up CoreData property changes after edits)

private struct PredefinedTransactionRow: View {
    @Bindable var transaction: PredefinedTransaction

    var body: some View {
        SettingsTransactionRow(
            desc: transaction.desc ?? "No Description",
            amount: transaction.amount,
            isIncome: transaction.isIncome
        )
    }
}

private struct QuickAddTransactionRow: View {
    @Bindable var transaction: QuickAddTransaction

    var body: some View {
        SettingsTransactionRow(
            desc: transaction.desc ?? "No Description",
            amount: transaction.amount,
            isIncome: transaction.isIncome
        )
    }
}

// MARK: - Shared row layout for predefined + quick-add

private struct SettingsTransactionRow: View {
    let desc: String
    let amount: Double
    let isIncome: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isIncome ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(isIncome ? FinanceTheme.income : FinanceTheme.expense)
                .imageScale(.large)

            VStack(alignment: .leading, spacing: 2) {
                Text(desc)
                    .font(.body)
                    .foregroundColor(.primary)
                Text(isIncome ? "Income" : "Expense")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(signedAmount.formattedAsCurrency())
                .font(.body.weight(.semibold))
                .foregroundStyle(isIncome ? FinanceTheme.income : FinanceTheme.expense)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private var signedAmount: Double {
        let magnitude = abs(amount)
        return isIncome ? magnitude : -magnitude
    }
}
