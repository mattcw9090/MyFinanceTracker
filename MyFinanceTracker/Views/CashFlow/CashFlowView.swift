import SwiftUI

struct CashFlowView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: CashFlowItem.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CashFlowItem.name, ascending: true)]
    )
    private var cashFlowItems: FetchedResults<CashFlowItem>

    @State private var showingAddOwedToMe = false
    @State private var showingAddIOwe = false
    @State private var cashFlowItemToEdit: CashFlowItem?

    var body: some View {
        NavigationView {
            List {
                cashFlowSection(
                    title: "Who owes me money",
                    items: cashFlowItems.filter { $0.isOwedToMe },
                    emptyMessage: "No one owes you money.",
                    emptyImage: "person.fill.questionmark"
                )
                
                cashFlowSection(
                    title: "Who I owe money",
                    items: cashFlowItems.filter { !$0.isOwedToMe },
                    emptyMessage: "You don't owe money to anyone.",
                    emptyImage: "person.fill.checkmark"
                )
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Cash Flow", displayMode: .inline)
            .navigationBarItems(trailing: addButton)
            .sheet(isPresented: $showingAddOwedToMe) {
                NavigationView {
                    AddCashFlowItemView(isDefaultOwedToMe: true)
                        .environment(\.managedObjectContext, viewContext)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingAddIOwe) {
                NavigationView {
                    AddCashFlowItemView(isDefaultOwedToMe: false)
                        .environment(\.managedObjectContext, viewContext)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $cashFlowItemToEdit) { item in
                NavigationView {
                    EditCashFlowItemView(item: item)
                        .environment(\.managedObjectContext, viewContext)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var addButton: some View {
        Menu {
            Button(action: { showingAddOwedToMe = true }) {
                Label("Add Owed to Me", systemImage: "arrow.down.circle.fill")
            }
            Button(action: { showingAddIOwe = true }) {
                Label("Add I Owe", systemImage: "arrow.up.circle.fill")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
        }
    }

    private func cashFlowSection(title: String, items: [CashFlowItem], emptyMessage: String, emptyImage: String) -> some View {
        Section(header: Text(title).font(.title2).bold()) {
            if items.isEmpty {
                EmptyStateView(message: emptyMessage, imageName: emptyImage)
            } else {
                ForEach(items, id: \.objectID) { item in
                    CashFlowRowView(item: item)
                        .listRowInsets(EdgeInsets())
                        .onTapGesture { cashFlowItemToEdit = item }
                        .swipeActions {
                            Button(role: .destructive) { delete(item) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                cashFlowItemToEdit = item
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    private func delete(_ item: CashFlowItem) {
        viewContext.delete(item)
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
