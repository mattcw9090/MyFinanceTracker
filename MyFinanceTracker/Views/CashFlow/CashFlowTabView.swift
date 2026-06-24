import SwiftUI

struct CashFlowTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: CashFlowItem.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CashFlowItem.name, ascending: true)]
    )
    private var cashFlowItems: FetchedResults<CashFlowItem>

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
            case .edit(let item): return "edit-\(item.objectID.uriRepresentation().absoluteString)"
            }
        }
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

                VStack(spacing: 0) {
                    summaryCard
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

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
            }
            .navigationTitle("Cash Flow")
            .navigationBarTitleDisplayMode(.inline)
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
        HStack(spacing: 10) {
            summaryPill(label: "Owed to Me", amount: totalOwedToMe, tint: .green)
            summaryPill(label: "I Owe", amount: totalIOwe, tint: .red)
            summaryPill(label: "Net", amount: netCashFlow, tint: netCashFlow >= 0 ? .green : .red)
        }
    }

    private func summaryPill(label: String, amount: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
            Text(amount.formattedAsCurrency())
                .font(.subheadline.weight(.bold))
                .foregroundColor(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(.snappy, value: amount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                .foregroundColor(.accentColor)
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: PresentedSheet) -> some View {
        switch sheet {
        case .addOwedToMe:
            NavigationStack {
                AddCashFlowItemView(isDefaultOwedToMe: true)
                    .environment(\.managedObjectContext, viewContext)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        case .addIOwe:
            NavigationStack {
                AddCashFlowItemView(isDefaultOwedToMe: false)
                    .environment(\.managedObjectContext, viewContext)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        case .bulkAdd:
            NavigationStack {
                BulkAddCashFlowItemsView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        case .edit(let item):
            NavigationStack {
                EditCashFlowItemView(item: item)
                    .environment(\.managedObjectContext, viewContext)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func cashFlowSection(title: String, items: [CashFlowItem], emptyMessage: String, emptyImage: String) -> some View {
        Section(header:
            Text(title)
                .font(.title2)
                .bold()
                .foregroundColor(.primary)
        ) {
            if items.isEmpty {
                EmptyStateView(message: emptyMessage, imageName: emptyImage)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(items, id: \.objectID) { item in
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
                        .tint(item.isSettled ? .gray : .green)
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
                        .tint(.orange)
                    }
                }
            }
        }
    }

    private func delete(_ item: CashFlowItem) {
        viewContext.delete(item)
        saveContext()
    }

    private func toggleSettled(_ item: CashFlowItem) {
        item.isSettled.toggle()
        saveContext()
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error.localizedDescription)")
        }
    }
}

struct EmptyStateView: View {
    var message: String
    var imageName: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: imageName)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(message)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
