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
                Section(header:
                    HStack {
                        Text("Who owes me money")
                            .font(.headline)
                        Spacer()
                        Button(action: { showingAddOwedToMe = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                                .imageScale(.large)
                        }
                        .accessibilityLabel("Add People who owe me money")
                    }
                ) {
                    let owedToMeItems = cashFlowItems.filter { $0.isOwedToMe }
                    if owedToMeItems.isEmpty {
                        Text("No one owes you money.")
                            .foregroundColor(.gray)
                            .italic()
                    } else {
                        ForEach(owedToMeItems, id: \.objectID) { item in
                            CashFlowRowView(item: item)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteCashFlowItem(item)
                                    } label: {
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
                    }
                }

                Section(header:
                    HStack {
                        Text("Who I owe money")
                            .font(.headline)
                        Spacer()
                        Button(action: { showingAddIOwe = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.red)
                                .imageScale(.large)
                        }
                        .accessibilityLabel("Add People I owe money to")
                    }
                ) {
                    let iOweItems = cashFlowItems.filter { !$0.isOwedToMe }
                    if iOweItems.isEmpty {
                        Text("You don't owe money to anyone.")
                            .foregroundColor(.gray)
                            .italic()
                    } else {
                        ForEach(iOweItems, id: \.objectID) { item in
                            CashFlowRowView(item: item)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteCashFlowItem(item)
                                    } label: {
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
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Cash Flow")
            // Removed the single "+" button from navigation bar
            .sheet(isPresented: $showingAddOwedToMe) {
                NavigationView {
                    AddCashFlowItemView(isDefaultOwedToMe: true)
                        .environment(\.managedObjectContext, viewContext)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingAddIOwe) {
                NavigationView {
                    AddCashFlowItemView(isDefaultOwedToMe: false)
                        .environment(\.managedObjectContext, viewContext)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $cashFlowItemToEdit) { item in
                NavigationView {
                    EditCashFlowItemView(item: item)
                        .environment(\.managedObjectContext, viewContext)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func deleteCashFlowItem(_ item: CashFlowItem) {
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
