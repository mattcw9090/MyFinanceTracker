import SwiftUI
import CoreData

struct TransactionsView: View {
    enum ActiveAlert: Identifiable {
        case reset, initializeWeek, success, noPredefinedTransactions

        var id: Int { hashValue }
    }

    let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    @State private var showingAddIncome = false
    @State private var showingAddExpense = false
    @State private var selectedDay: String = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX") // Ensures consistent day names
        formatter.dateFormat = "EEEE" // Full day name (e.g., "Monday")
        let today = formatter.string(from: Date())
        // Ensure that the day name matches one in the 'days' array
        if ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].contains(today) {
            return today
        } else {
            return "Monday" // Fallback to "Monday" if for some reason today doesn't match
        }
    }()
    @State private var activeAlert: ActiveAlert?

    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Transaction.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.dayOfWeek, ascending: true)],
        predicate: NSPredicate(format: "isCompleted == false"),
        animation: .default
    )
    private var transactions: FetchedResults<Transaction>

    @EnvironmentObject var netIncomeManager: NetIncomeManager

    var body: some View {
        NavigationView {
            VStack {
                NetIncomeView()
                    .padding(.horizontal)
                    .padding(.top)

                HStack(spacing: 20) {
                    Button(action: { showingAddIncome.toggle() }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Income")
                                .fontWeight(.semibold)
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.green)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    }
                    .sheet(isPresented: $showingAddIncome) {
                        AddTransactionView(isIncome: true, defaultDay: selectedDay)
                            .environment(\.managedObjectContext, viewContext)
                            .environmentObject(netIncomeManager)
                    }

                    Button(action: { showingAddExpense.toggle() }) {
                        HStack {
                            Image(systemName: "minus.circle.fill")
                            Text("Add Expense")
                                .fontWeight(.semibold)
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.red)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    }
                    .sheet(isPresented: $showingAddExpense) {
                        AddTransactionView(isIncome: false, defaultDay: selectedDay)
                            .environment(\.managedObjectContext, viewContext)
                            .environmentObject(netIncomeManager)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)

                TabView(selection: $selectedDay) {
                    ForEach(days, id: \.self) { day in
                        VStack(alignment: .leading) {
                            Text(day)
                                .font(.largeTitle)
                                .bold()
                                .padding(.bottom, 10)

                            TransactionListView(day: day, transactions: transactionsForDay(day))
                        }
                        .padding()
                        .tag(day)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            }
            .navigationBarTitle("My Finance", displayMode: .inline)
            .navigationBarItems(
                leading: HStack(spacing: 20) {
                    Button(action: { activeAlert = .reset }) {
                        Image(systemName: "arrow.counterclockwise")
                            .imageScale(.large)
                            .foregroundColor(.red)
                    }
                    .accessibilityLabel("Reset")

                    Button(action: { activeAlert = .initializeWeek }) {
                        Image(systemName: "calendar.badge.plus")
                            .imageScale(.large)
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Initialize Week")
                }
            )
            .alert(item: $activeAlert) { alertType in
                switch alertType {
                case .reset:
                    return Alert(
                        title: Text("Confirm Reset"),
                        message: Text("Are you sure you want to reset all transactions and net income? This action cannot be undone."),
                        primaryButton: .destructive(Text("Reset")) { resetAll() },
                        secondaryButton: .cancel()
                    )
                case .initializeWeek:
                    return Alert(
                        title: Text("Confirm Initialize Week"),
                        message: Text("This will delete all existing transactions, reset net income to $0.00, and populate with your predefined transactions. This action cannot be undone."),
                        primaryButton: .destructive(Text("Initialize")) { initializeWeek() },
                        secondaryButton: .cancel()
                    )
                case .success:
                    return Alert(
                        title: Text("Operation Successful"),
                        message: Text("All transactions have been deleted and net income has been reset to $0.00."),
                        dismissButton: .default(Text("OK")) { activeAlert = nil }
                    )
                case .noPredefinedTransactions:
                    return Alert(
                        title: Text("No Predefined Transactions"),
                        message: Text("You have not set up any predefined transactions. Please add them in the settings."),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .accentColor(.purple)
        }
    }
}

extension TransactionsView {
    private func transactionsForDay(_ day: String) -> [Transaction] {
        transactions.filter { $0.dayOfWeek == day }
    }

    private func resetAll() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Transaction.fetchRequest()
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDeleteRequest.resultType = .resultTypeObjectIDs

        do {
            let result = try viewContext.execute(batchDeleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
            }
            netIncomeManager.resetNetIncome()
            activeAlert = .success
        } catch {
            print("Failed to reset: \(error.localizedDescription)")
        }
    }

    private func initializeWeek() {
        resetAll()

        let fetchRequest: NSFetchRequest<PredefinedTransaction> = PredefinedTransaction.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PredefinedTransaction.dayOfWeek, ascending: true)]

        do {
            let predefinedTransactions = try viewContext.fetch(fetchRequest)

            if predefinedTransactions.isEmpty {
                activeAlert = .noPredefinedTransactions
            } else {
                for predefinedTransaction in predefinedTransactions {
                    let newTransaction = Transaction(context: viewContext)
                    newTransaction.id = UUID()
                    newTransaction.desc = predefinedTransaction.desc
                    newTransaction.amount = predefinedTransaction.amount
                    newTransaction.dayOfWeek = predefinedTransaction.dayOfWeek
                    newTransaction.isCompleted = false
                    newTransaction.isIncome = predefinedTransaction.isIncome

                    netIncomeManager.adjustNetIncome(by: predefinedTransaction.amount, isIncome: predefinedTransaction.isIncome, isDeletion: false)
                }

                try viewContext.save()
                activeAlert = .success
            }
        } catch {
            print("Failed to add predefined transactions: \(error.localizedDescription)")
        }
    }
}