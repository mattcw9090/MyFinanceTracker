import SwiftUI
import SwiftData

struct CashFlowTabView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CashFlowItem.name) private var cashFlowItems: [CashFlowItem]

    @State private var presentedSheet: PresentedSheet?

    enum PresentedSheet: Identifiable {
        case addOwedToMe
        case addIOwe
        case bulkAdd
        case edit(CashFlowItem)

        var id: String {
            switch self {
            case .addOwedToMe: return "addOwedToMe"
            case .addIOwe: return "addIOwe"
            case .bulkAdd: return "bulkAdd"
            case .edit(let item): return "edit-\(item.id.uuidString)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                    summaryCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 10)

                    List {
                        cashFlowSection(
                            title: "Who owes me money",
                            items: owedToMeItems,
                            emptyMessage: "No one owes you money.",
                            emptyImage: "person.fill.questionmark"
                        )

                        cashFlowSection(
                            title: "Who I owe money",
                            items: iOweItems,
                            emptyMessage: "You don't owe money to anyone.",
                            emptyImage: "person.fill.checkmark"
                        )
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .accessibilityIdentifier("cashFlowListView")
            }
            .financeBackground()
            .navigationTitle("Cash Flow")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    addMenu
                }
            }
            .sheet(item: $presentedSheet, content: sheetContent)
        }
    }

    // MARK: - Derived state

    private var owedToMeItems: [CashFlowItem] {
        cashFlowItems.filter { $0.isOwedToMe }
    }

    private var iOweItems: [CashFlowItem] {
        cashFlowItems.filter { !$0.isOwedToMe }
    }

    private var totalOwedToMe: Double {
        owedToMeItems.filter { !$0.isSettled }.reduce(0) { $0 + $1.amount }
    }

    private var totalIOwe: Double {
        iOweItems.filter { !$0.isSettled }.reduce(0) { $0 + $1.amount }
    }

    private var netCashFlow: Double {
        totalOwedToMe - totalIOwe
    }

    // MARK: - Subviews

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("NET POSITION")
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(netCashFlow.formattedAsCurrency())
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(netCashFlow >= 0 ? FinanceTheme.income : FinanceTheme.expense)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Divider()

            HStack(spacing: 0) {
                summaryMetric(label: "Coming in", amount: totalOwedToMe, tint: FinanceTheme.income)
                Divider().frame(height: 38)
                summaryMetric(label: "Going out", amount: totalIOwe, tint: FinanceTheme.expense)
            }
        }
        .financeCard(padding: 20)
    }

    private func summaryMetric(label: String, amount: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amount.formattedAsCurrency())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(.snappy, value: amount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private var addMenu: some View {
        Menu {
            Button { presentedSheet = .addOwedToMe } label: {
                Label("Add Owed to Me", systemImage: "arrow.down.circle.fill")
            }
            Button { presentedSheet = .addIOwe } label: {
                Label("Add I Owe", systemImage: "arrow.up.circle.fill")
            }
            Divider()
            Button { presentedSheet = .bulkAdd } label: {
                Label("Bulk Add (Split Bill)", systemImage: "person.3.fill")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(FinanceTheme.accent)
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: PresentedSheet) -> some View {
        switch sheet {
        case .addOwedToMe:
            NavigationStack {
                CashFlowItemFormView(mode: .add(defaultOwedToMe: true))
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        case .addIOwe:
            NavigationStack {
                CashFlowItemFormView(mode: .add(defaultOwedToMe: false))
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        case .bulkAdd:
            NavigationStack {
                BulkAddCashFlowItemsView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        case .edit(let item):
            NavigationStack {
                CashFlowItemFormView(mode: .edit(item))
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func cashFlowSection(title: String, items: [CashFlowItem], emptyMessage: String, emptyImage: String) -> some View {
        Section(header:
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
        ) {
            if items.isEmpty {
                EmptyStateView(message: emptyMessage, imageName: emptyImage)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(items, id: \.id) { item in
                    CashFlowRowView(item: item) {
                        presentedSheet = .edit(item)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            toggleSettled(item)
                        } label: {
                            Label(
                                item.isSettled ? "Unmark" : "Mark Paid",
                                systemImage: item.isSettled ? "arrow.uturn.backward.circle" : "checkmark.circle.fill"
                            )
                        }
                        .tint(item.isSettled ? .gray : FinanceTheme.income)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { delete(item) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            presentedSheet = .edit(item)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(FinanceTheme.amber)
                    }
                }
            }
        }
    }

    private func delete(_ item: CashFlowItem) {
        modelContext.delete(item)
        modelContext.saveOrLog()
    }

    private func toggleSettled(_ item: CashFlowItem) {
        item.isSettled.toggle()
        modelContext.saveOrLog()
    }
}

struct EmptyStateView: View {
    var message: String
    var imageName: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: imageName)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(FinanceTheme.accent)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
