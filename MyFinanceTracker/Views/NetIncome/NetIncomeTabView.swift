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
    @State private var showingImportSessions = false
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
            VStack(spacing: 0) {
                    NetIncomeBalanceCard()
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 14)

                    HStack(spacing: 12) {
                        Button(action: { showingAddIncome.toggle() }) {
                            Label("Income", systemImage: "plus")
                        }
                        .buttonStyle(FinanceActionButtonStyle(tint: FinanceTheme.income))
                        .accessibilityIdentifier("addIncomeButton")
                        .sheet(isPresented: $showingAddIncome) {
                            AddTransactionView(isIncome: true, selectedDay: $selectedDay)
                                .environmentObject(netIncomeManager)
                        }

                        Button(action: { showingAddExpense.toggle() }) {
                            Label("Expense", systemImage: "minus")
                        }
                        .buttonStyle(FinanceActionButtonStyle(tint: FinanceTheme.expense))
                        .accessibilityIdentifier("addExpenseButton")
                        .sheet(isPresented: $showingAddExpense) {
                            AddTransactionView(isIncome: false, selectedDay: $selectedDay)
                                .environmentObject(netIncomeManager)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)

                    daySelector

                    TabView(selection: $selectedDay) {
                        ForEach(days, id: \.self) { day in
                            VStack(alignment: .leading, spacing: 12) {
                                FinanceSectionLabel(
                                    title: day,
                                    detail: transactionSummary(for: day)
                                )
                                    .accessibilityIdentifier("selectedDay")

                                TransactionListView(day: day, transactions: transactionsForDay(day))
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .tag(day)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .financeBackground()
            .navigationTitle("My Week")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 20) {
                        Button { activeAlert = .reset } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(FinanceTheme.expense)
                        }
                        .accessibilityIdentifier("resetButton")

                        Button { activeAlert = .initializeWeek } label: {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundStyle(FinanceTheme.accent)
                        }
                        .accessibilityIdentifier("initializeWeekButton")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingImportSessions = true } label: {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundStyle(FinanceTheme.accent)
                    }
                    .accessibilityIdentifier("importSessionsButton")
                }
            }
            .sheet(isPresented: $showingImportSessions) {
                ImportSessionsView()
                    .environmentObject(netIncomeManager)
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

    private var daySelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        Button {
                            withAnimation(.snappy) { selectedDay = day }
                        } label: {
                            VStack(spacing: 4) {
                                Text(String(day.prefix(1)))
                                    .font(.caption.weight(.semibold))
                                Text(day == Weekday.today ? "Today" : String(day.prefix(3)))
                                    .font(.caption2.weight(.medium))
                            }
                            .foregroundStyle(selectedDay == day ? .white : .secondary)
                            .frame(width: 54, height: 48)
                            .background(
                                selectedDay == day ? FinanceTheme.accent : FinanceTheme.surface,
                                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .id(day)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: selectedDay) { _, day in
                withAnimation(.snappy) { proxy.scrollTo(day, anchor: .center) }
            }
        }
    }

    private func transactionSummary(for day: String) -> String {
        let count = transactionsForDay(day).count
        return count == 1 ? "1 planned item" : "\(count) planned items"
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
                    let scheduledDays = predefinedTransaction.repeatsEveryDay
                        ? Weekday.allNames
                        : [predefinedTransaction.dayOfWeek ?? Weekday.today]

                    for day in scheduledDays {
                        let newTransaction = Transaction(
                            desc: predefinedTransaction.desc,
                            amount: predefinedTransaction.amount,
                            dayOfWeek: day,
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
                }

                try modelContext.save()
                activeAlert = .success
            }
        } catch {
            print("Failed to add predefined transactions: \(error.localizedDescription)")
        }
    }
}
