import SwiftUI
import SwiftData

struct TransactionListView: View {
    let day: String
    let transactions: [Transaction]

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var netIncomeManager: NetIncomeManager

    @State private var cashFlowPrompt: CashFlowPrompt?
    @State private var courtCostDraft: CourtCostDraft?
    @State private var completionMessage: String?
    @State private var isCompleting = false

    var body: some View {
        Group {
            if transactions.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(FinanceTheme.accent)
                        Text("Nothing planned")
                            .font(.headline)
                        Text("Add income or an expense for \(day).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .financeCard(padding: 28)
                }
                .refreshable {
                    await FinanceCloud.shared.sync(in: modelContext)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(transactions, id: \.id) { transaction in
                            NavigationLink(destination: EditTransactionView(transaction: transaction)
                                            .environmentObject(netIncomeManager)) {
                                TransactionRowView(
                                    transaction: transaction,
                                    onComplete: {
                                        complete(transaction)
                                    },
                                    onDelete: {
                                        deleteTransaction(transaction)
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await FinanceCloud.shared.sync(in: modelContext)
                }
            }
        }
        .alert(item: $cashFlowPrompt) { prompt in
            Alert(
                title: Text("Add to Cash Flow"),
                message: Text("Do you want to add this completed income transaction to the 'Who owes me' section?"),
                primaryButton: .default(Text("Yes")) {
                    courtCostDraft = CourtCostDraft(transaction: prompt.transaction)
                },
                secondaryButton: .cancel {
                    finish(prompt.transaction, addToCashFlow: false)
                }
            )
        }
        .sheet(item: $courtCostDraft) { draft in
            AddCourtCostView(
                transactionName: draft.transaction.desc ?? "Unnamed Transaction",
                transactionAmount: draft.transaction.amount,
                onCancel: {
                    finish(draft.transaction, addToCashFlow: false)
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
            cashFlowPrompt = CashFlowPrompt(transaction: transaction)
        } else {
            finish(transaction, addToCashFlow: false)
        }
    }

    /// Expenses, No, and Cancel tick the row only. Add also sends the court cost and names.
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

private struct CashFlowPrompt: Identifiable {
    let id = UUID()
    let transaction: Transaction
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
