import SwiftUI
import SwiftData

struct CashFlowTabView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CashFlowItem.name) private var cashFlowItems: [CashFlowItem]

    @State private var presentedSheet: PresentedSheet?
    @State private var pendingDelete: CashFlowItem?
    @State private var showingDeleteConfirm = false
    @State private var showOwedSettled = false
    @State private var showIOweSettled = false

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
                List {
                    cashFlowSection(
                        title: "Who owes me money",
                        items: owedToMeItems,
                        emptyMessage: "No one owes you money.",
                        emptyImage: "person.fill.questionmark",
                        showSettled: $showOwedSettled
                    )

                    cashFlowSection(
                        title: "Who I owe money",
                        items: iOweItems,
                        emptyMessage: "You don't owe money to anyone.",
                        emptyImage: "person.fill.checkmark",
                        showSettled: $showIOweSettled
                    )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .accessibilityIdentifier("cashFlowListView")
                .refreshable {
                    await FinanceCloud.shared.sync(in: modelContext)
                }
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
            .alert("Delete this item?", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let item = pendingDelete {
                        delete(item)
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            } message: {
                Text("This removes it from cash flow.")
            }
        }
    }

    // MARK: - Derived state

    private var owedToMeItems: [CashFlowItem] {
        cashFlowItems.filter { $0.deletedAt == nil && $0.isOwedToMe }
    }

    private var iOweItems: [CashFlowItem] {
        cashFlowItems.filter { $0.deletedAt == nil && !$0.isOwedToMe }
    }

    // MARK: - Subviews

    private var addMenu: some View {
        Menu {
            Button { presentedSheet = .addOwedToMe } label: {
                Label("Add Owed to Me", systemImage: FinanceMark.income)
            }
            Button { presentedSheet = .addIOwe } label: {
                Label("Add I Owe", systemImage: FinanceMark.expense)
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

    private func cashFlowSection(
        title: String,
        items: [CashFlowItem],
        emptyMessage: String,
        emptyImage: String,
        showSettled: Binding<Bool>
    ) -> some View {
        let open = items.filter { !$0.isSettled }
        let settled = items.filter { $0.isSettled }
        let expanded = showSettled.wrappedValue
        return Section {
            if items.isEmpty {
                EmptyStateView(message: emptyMessage, imageName: emptyImage)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(sectionRows(open: open, settled: settled, expanded: expanded)) { row in
                    switch row.kind {
                    case .item(let item):
                        cashFlowRow(item)
                    case .settledToggle(let count):
                        Button {
                            showSettled.wrappedValue.toggle()
                        } label: {
                            HStack {
                                Text("Settled")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(count)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("settledDisclosure")
                        .accessibilityLabel("Settled")
                        .accessibilityValue(expanded ? "expanded" : "collapsed")
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                if !items.isEmpty {
                    Text(outstanding(items).formattedAsCurrency())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    private func cashFlowRow(_ item: CashFlowItem) -> some View {
        CashFlowRowView(item: item) {
            presentedSheet = .edit(item)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDelete = item
                showingDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityIdentifier("deleteButton")
            Button {
                presentedSheet = .edit(item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(FinanceTheme.amberFill)
        }
    }

    private struct SectionRow: Identifiable {
        enum Kind {
            case item(CashFlowItem)
            case settledToggle(count: Int)
        }

        let id: String
        let kind: Kind
    }

    private func sectionRows(open: [CashFlowItem], settled: [CashFlowItem], expanded: Bool) -> [SectionRow] {
        var rows = open.map { SectionRow(id: $0.id.uuidString, kind: .item($0)) }
        guard !settled.isEmpty else { return rows }
        rows.append(SectionRow(id: "settled-toggle", kind: .settledToggle(count: settled.count)))
        if expanded {
            rows.append(contentsOf: settled.map {
                SectionRow(id: "settled-\($0.id.uuidString)", kind: .item($0))
            })
        }
        return rows
    }

    private func outstanding(_ items: [CashFlowItem]) -> Double {
        items.reduce(0) { sum, item in
            guard !item.isSettled else { return sum }
            let magnitude = abs(item.amount)
            return sum + (item.isOwedToMe ? magnitude : -magnitude)
        }
    }

    private func delete(_ item: CashFlowItem) {
        item.markDeleted()
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
