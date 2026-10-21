import SwiftUI
import SwiftData

struct TransactionListView: View {
    let day: String
    let transactions: [Transaction]
    var onOpen: (Transaction) -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var netIncomeManager: NetIncomeManager

    @State private var cashFlowTransaction: Transaction?
    @State private var showingCashFlowPrompt = false
    @State private var courtCostDraft: CourtCostDraft?
    @State private var pendingDelete: Transaction?
    @State private var showingDeleteConfirm = false
    @State private var completionMessage: String?
    @State private var isCompleting = false

    var body: some View {
        List {
            if transactions.isEmpty {
                Text("Nothing planned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("emptyDay")
            } else {
                ForEach(transactions, id: \.id) { transaction in
                    TransactionRowView(transaction: transaction) {
                        onOpen(transaction)
                    } onComplete: {
                        complete(transaction)
                    }
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDelete = transaction
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityIdentifier("deleteButton")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("selectedDay")
        .accessibilityLabel(day)
        .refreshable {
            await FinanceCloud.shared.sync(in: modelContext)
        }
        .alert(
            "Add to Cash Flow",
            isPresented: $showingCashFlowPrompt
        ) {
            Button("Tick") {
                if let transaction = cashFlowTransaction {
                    applyTickChoice(.tick, to: transaction)
                }
                cashFlowTransaction = nil
            }
            Button("Add to who owes me") {
                if let transaction = cashFlowTransaction {
                    applyTickChoice(.addToCashFlow, to: transaction)
                }
                cashFlowTransaction = nil
            }
            Button("Cancel", role: .cancel) {
                if let transaction = cashFlowTransaction {
                    applyTickChoice(.cancel, to: transaction)
                }
                cashFlowTransaction = nil
            }
        } message: {
            Text("Tick marks it done. Add to who owes me also records what is still owed.")
        }
        .sheet(item: $courtCostDraft) { draft in
            AddCourtCostView(
                transactionName: draft.transaction.desc ?? "Unnamed Transaction",
                transactionAmount: draft.transaction.amount,
                onCancel: {
                    applyTickChoice(.cancel, to: draft.transaction)
                    courtCostDraft = nil
                },
                onAdd: { additionalCost, splitNames in
                    finish(
                        draft.transaction,
                        addToCashFlow: true,
                        additionalCost: additionalCost,
                        splitNames: splitNames
                    )
                    courtCostDraft = nil
                }
            )
            .interactiveDismissDisabled()
        }
        .alert("Delete this transaction?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let transaction = pendingDelete {
                    deleteTransaction(transaction)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("This removes it from the week and updates the balance.")
        }
        .alert("Couldn't tick this transaction", isPresented: Binding(
            get: { completionMessage != nil },
            set: { if !$0 { completionMessage = nil } }
        )) {
            Button("OK", role: .cancel) { completionMessage = nil }
        } message: {
            Text(completionMessage ?? "")
        }
    }

    private func complete(_ transaction: Transaction) {
        if transaction.isIncome {
            cashFlowTransaction = transaction
            showingCashFlowPrompt = true
        } else {
            applyTickChoice(.tick, to: transaction)
        }
    }

    /// Cancel returns before any completion request. Tick completes the row.
    /// Add to who owes me opens the court-cost sheet, which completes on Add.
    private func applyTickChoice(_ choice: IncomeTickChoice, to transaction: Transaction) {
        guard shouldCompleteTransaction(for: choice) else { return }
        switch choice {
        case .tick:
            finish(transaction, addToCashFlow: false)
        case .addToCashFlow:
            courtCostDraft = CourtCostDraft(transaction: transaction)
        case .cancel:
            break
        }
    }

    /// Cash-flow items are created in Supabase and arrive on the following pull.
    private func finish(
        _ transaction: Transaction,
        addToCashFlow: Bool,
        additionalCost: Double = 0,
        splitNames: [String]? = nil
    ) {
        guard !transaction.isCompleted, !isCompleting else { return }
        isCompleting = true
        Task {
            defer { isCompleting = false }
            do {
                try await FinanceCloud.shared.completeTransaction(
                    transaction,
                    addToCashFlow: addToCashFlow,
                    additionalCost: additionalCost,
                    splitNames: splitNames,
                    in: modelContext
                )
            } catch {
                completionMessage = error.localizedDescription
            }
        }
    }

    private func deleteTransaction(_ transaction: Transaction) {
        netIncomeManager.adjustNetIncome(by: transaction.amount, isIncome: transaction.isIncome, isDeletion: true)
        transaction.markDeleted()
        modelContext.saveOrLog()
    }
}

private struct CourtCostDraft: Identifiable {
    let id = UUID()
    let transaction: Transaction
}

private struct AddCourtCostView: View {
    let transactionName: String
    let transactionAmount: Double
    let onCancel: () -> Void
    let onAdd: (_ additionalCost: Double, _ splitNames: [String]) -> Void

    @State private var additionalCostString = ""
    @State private var splitNames: [String]

    init(
        transactionName: String,
        transactionAmount: Double,
        onCancel: @escaping () -> Void,
        onAdd: @escaping (_ additionalCost: Double, _ splitNames: [String]) -> Void
    ) {
        self.transactionName = transactionName
        self.transactionAmount = transactionAmount
        self.onCancel = onCancel
        self.onAdd = onAdd
        _splitNames = State(initialValue: Self.splitNames(from: transactionName))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(transactionName)
                        .font(.headline)
                    Text(transactionAmount.formattedAsCurrency())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FinanceTheme.income)
                        .monospacedDigit()
                } header: {
                    Text("Income Transaction")
                }

                Section {
                    TextField("Enter amount", text: $additionalCostString)
                        .decimalInput($additionalCostString)
                        .accessibilityIdentifier("AddCourtCost_AmountField")
                } header: {
                    Text("Additional Court Cost")
                }

                Section {
                    Button {
                        splitNames.append("")
                    } label: {
                        Label("Add Person", systemImage: "plus.circle")
                    }
                    .accessibilityIdentifier("AddCourtCost_AddPersonButton")

                    ForEach(splitNames.indices, id: \.self) { index in
                        TextField("Name", text: $splitNames[index])
                            .accessibilityIdentifier("AddCourtCost_NameField_\(index)")
                    }
                    .onDelete { offsets in
                        splitNames.remove(atOffsets: offsets)
                    }
                } header: {
                    Text("Split")
                } footer: {
                    Text("Names are prefilled from commas in the transaction title. Leave the split empty to add one cash-flow item for the full amount.")
                }
            }
            .navigationTitle("Add Court Cost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("AddCourtCost_CancelButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        onAdd(Double(additionalCostString) ?? 0, splitNames)
                    }
                    .accessibilityIdentifier("AddCourtCost_AddButton")
                }
            }
        }
    }

    private static func splitNames(from transactionName: String) -> [String] {
        transactionName
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
