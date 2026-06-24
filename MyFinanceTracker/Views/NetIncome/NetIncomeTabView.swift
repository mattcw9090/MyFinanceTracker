import SwiftUI
import SwiftData

struct NetIncomeTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var netIncomeManager: NetIncomeManager

    enum ActiveAlert: Identifiable {
        case reset, initializeWeek, success, noPredefinedTransactions
        var id: Int { hashValue }
    }

    let days = Weekday.allNames

    @State private var showingAddIncome = false
    @State private var showingAddExpense = false
    @State private var selectedDay: String = Weekday.today
    @State private var activeAlert: ActiveAlert?

    @Query(
        filter: #Predicate<Transaction> { !$0.isCompleted },
        sort: \Transaction.dayOfWeek,
        animation: .default
    )
    private var transactions: [Transaction]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemBackground)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                VStack {
                    NetIncomeBalanceCard()
                        .padding(.horizontal)
                        .padding(.top)
                        .padding(.bottom, 16)

                    // Add Income/Expense Buttons
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
                        .accessibilityIdentifier("addIncomeButton")
                        .sheet(isPresented: $showingAddIncome) {
                            AddTransactionView(isIncome: true, selectedDay: $selectedDay)
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
                        .accessibilityIdentifier("addExpenseButton")
                        .sheet(isPresented: $showingAddExpense) {
                            AddTransactionView(isIncome: false, selectedDay: $selectedDay)
                                .environmentObject(netIncomeManager)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                    // Daily Transactions TabView
                    TabView(selection: $selectedDay) {
                        ForEach(days, id: \.self) { day in
                            VStack(alignment: .leading) {
                                Text(day)
                                    .font(.largeTitle)
                                    .bold()
                                    .padding(.bottom, 10)
                                    .accessibilityIdentifier("selectedDay")

                                TransactionListView(day: day, transactions: transactionsForDay(day))
                                    .listStyle(PlainListStyle())
                            }
                            .padding()
                            .tag(day)
                        }

                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .automatic))
                }
            }
            .navigationTitle("My Finance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 20) {
                        Button { activeAlert = .reset } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .imageScale(.large)
                                .foregroundColor(.red)
                        }
                        .accessibilityIdentifier("resetButton")

                        Button { activeAlert = .initializeWeek } label: {
                            Image(systemName: "calendar.badge.plus")
                                .imageScale(.large)
                                .foregroundColor(.blue)
                        }
                        .accessibilityIdentifier("initializeWeekButton")
                    }
                }
            }
            .alert(item: $activeAlert) { alertType in
                switch alertType {
                case .reset:
                    return Alert(
                        title: Text("Confirm Reset"),
                        message: Text("Are you sure you want to reset all transactions and net income?"),
                        primaryButton: .destructive(Text("Reset")) { resetAll() },
                        secondaryButton: .cancel()
                    )
                case .initializeWeek:
                    return Alert(
                        title: Text("Confirm Initialize Week"),
                        message: Text("This will delete all existing transactions and reset net income to $0.00."),
                        primaryButton: .destructive(Text("Initialize")) { initializeWeek() },
                        secondaryButton: .cancel()
                    )
                case .success:
                    return Alert(
                        title: Text("Operation Successful"),
                        message: Text("All transactions have been deleted and net income has been reset."),
                        dismissButton: .default(Text("OK")) { activeAlert = nil }
                    )
                case .noPredefinedTransactions:
                    return Alert(
                        title: Text("No Predefined Transactions"),
                        message: Text("You have not set up any predefined transactions."),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
    }

    private func transactionsForDay(_ day: String) -> [Transaction] {
        transactions.filter { $0.dayOfWeek == day }
    }

    private func resetAll() {
        do {
            try modelContext.delete(model: Transaction.self)
            netIncomeManager.resetNetIncome()
            activeAlert = .success
        } catch {
            print("Failed to reset: \(error.localizedDescription)")
        }
    }

    private func initializeWeek() {
        resetAll()

        do {
            let descriptor = FetchDescriptor<PredefinedTransaction>(
                sortBy: [SortDescriptor(\.dayOfWeek)]
            )
            let predefinedTransactions = try modelContext.fetch(descriptor)

            if predefinedTransactions.isEmpty {
                activeAlert = .noPredefinedTransactions
            } else {
                for predefinedTransaction in predefinedTransactions {
                    let newTransaction = Transaction(
                        desc: predefinedTransaction.desc,
                        amount: predefinedTransaction.amount,
                        dayOfWeek: predefinedTransaction.dayOfWeek,
                        isCompleted: false,
                        isIncome: predefinedTransaction.isIncome
                    )
                    modelContext.insert(newTransaction)

                    netIncomeManager.adjustNetIncome(
                        by: predefinedTransaction.amount,
                        isIncome: predefinedTransaction.isIncome,
                        isDeletion: false
                    )
                }

                try modelContext.save()
                activeAlert = .success
            }
        } catch {
            print("Failed to add predefined transactions: \(error.localizedDescription)")
        }
    }
}
