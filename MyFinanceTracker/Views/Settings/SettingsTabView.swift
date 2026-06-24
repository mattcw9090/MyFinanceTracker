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

    /// Trigger for refreshing the List when edits complete
    @State private var refreshID = UUID()

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
                    predefinedGroup
                    quickAddGroup
                }
                .id(refreshID)
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitle("Settings", displayMode: .inline)
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
                            .imageScale(.large)
                    }
                    .accessibilityIdentifier("Settings_AddMenu")
                }
            }
            // Add Predefined
            .sheet(isPresented: $showingAddPredefinedTransaction) {
                NavigationView {
                    AddPredefinedTransactionView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            // Edit Predefined
            .sheet(item: $predefinedTransactionToEdit) { transaction in
                NavigationView {
                    EditPredefinedTransactionView(transaction: transaction)
                        .environment(\.managedObjectContext, viewContext)
                }
                .onDisappear {
                    refreshID = UUID()
                }
            }
            // Add Quick Add
            .sheet(isPresented: $showingAddQuickAddTransaction) {
                NavigationView {
                    AddQuickAddTransactionView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            // Edit Quick Add
            .sheet(item: $quickAddTransactionToEdit) { transaction in
                NavigationView {
                    EditQuickAddTransactionView(transaction: transaction)
                        .environment(\.managedObjectContext, viewContext)
                }
                .onDisappear {
                    refreshID = UUID()
                }
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
                            SettingsTransactionRow(
                                desc: transaction.desc ?? "No Description",
                                amount: transaction.amount,
                                isIncome: transaction.isIncome
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                predefinedTransactionToEdit = transaction
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
                    SectionSubHeader(text: "Income", tint: .green)

                    ForEach(income, id: \.id) { transaction in
                        SettingsTransactionRow(
                            desc: transaction.desc ?? "No Description",
                            amount: transaction.amount,
                            isIncome: transaction.isIncome
                        )
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
                    SectionSubHeader(text: "Expense", tint: .red)

                    ForEach(expense, id: \.id) { transaction in
                        SettingsTransactionRow(
                            desc: transaction.desc ?? "No Description",
                            amount: transaction.amount,
                            isIncome: transaction.isIncome
                        )
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

// MARK: - Shared row layout for predefined + quick-add

private struct SettingsTransactionRow: View {
    let desc: String
    let amount: Double
    let isIncome: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isIncome ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundColor(isIncome ? .green : .red)
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

            Text(formattedAmount)
                .font(.body.weight(.semibold))
                .foregroundColor(isIncome ? .green : .red)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private var formattedAmount: String {
        let absAmount = abs(amount)
        let prefix = isIncome ? "$" : "-$"
        return "\(prefix)\(String(format: "%.2f", absAmount))"
    }
}
