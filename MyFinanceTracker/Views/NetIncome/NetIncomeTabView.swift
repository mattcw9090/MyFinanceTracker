import SwiftUI
import SwiftData

struct NetIncomeTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var netIncomeManager: NetIncomeManager

    enum ActiveAlert: Identifiable {
        case reset
        case initializeWeek(Double)
        case resetSuccess
        case initializeSuccess
        case noPredefinedTransactions

        var id: String {
            switch self {
            case .reset: return "reset"
            case .initializeWeek: return "initializeWeek"
            case .resetSuccess: return "resetSuccess"
            case .initializeSuccess: return "initializeSuccess"
            case .noPredefinedTransactions: return "noPredefinedTransactions"
            }
        }
    }

    let days = Weekday.allNames

    @State private var showingAddIncome = false
    @State private var showingAddExpense = false
    @State private var showingImportSessions = false
    @State private var selectedDay: String = Weekday.today
    @State private var editingTransactionID: UUID?
    @State private var activeAlert: ActiveAlert?
    @State private var weekErrorMessage: String?
    @State private var showWeekError = false

    @ScaledMetric(relativeTo: .caption) private var chipMinHeight: CGFloat = 44

    @Query(sort: \Transaction.dayOfWeek, animation: .default)
    private var transactions: [Transaction]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(weekRange)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 2)
                    .accessibilityIdentifier("weekDateRange")

                NetIncomeBalanceCard()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                HStack(spacing: 10) {
                    Button(action: { showingAddIncome.toggle() }) {
                        Label("Income", systemImage: FinanceMark.income)
                    }
                    .buttonStyle(FinanceActionButtonStyle(tint: FinanceTheme.incomeFill))
                    .accessibilityIdentifier("addIncomeButton")
                    .sheet(isPresented: $showingAddIncome) {
                        AddTransactionView(isIncome: true, selectedDay: $selectedDay)
                            .environmentObject(netIncomeManager)
                    }

                    Button(action: { showingAddExpense.toggle() }) {
                        Label("Expense", systemImage: FinanceMark.expense)
                    }
                    .buttonStyle(FinanceActionButtonStyle(tint: FinanceTheme.expenseFill))
                    .accessibilityIdentifier("addExpenseButton")
                    .sheet(isPresented: $showingAddExpense) {
                        AddTransactionView(isIncome: false, selectedDay: $selectedDay)
                            .environmentObject(netIncomeManager)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                daySelector
                    .padding(.bottom, 4)

                TransactionListView(
                    day: selectedDay,
                    transactions: transactionsForDay(selectedDay),
                    onOpen: { editingTransactionID = $0.id }
                )
            }
            .financeBackground()
            .navigationTitle("My Week")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    weekMenu
                }
            }
            .navigationDestination(isPresented: editingPresented) {
                if let transaction = transactions.first(where: { $0.id == editingTransactionID && $0.deletedAt == nil }) {
                    EditTransactionView(transaction: transaction)
                        .environmentObject(netIncomeManager)
                }
            }
            .sheet(isPresented: $showingImportSessions) {
                ImportSessionsView()
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
                case .initializeWeek(let total):
                    return Alert(
                        title: Text("Confirm Initialize Week"),
                        message: Text(initializeWeekConfirmationMessage(total: total)),
                        primaryButton: .destructive(Text("Initialize")) { initializeWeek() },
                        secondaryButton: .cancel()
                    )
                case .resetSuccess:
                    return Alert(
                        title: Text("Operation Successful"),
                        message: Text("All transactions have been deleted and net income has been reset."),
                        dismissButton: .default(Text("OK")) { activeAlert = nil }
                    )
                case .initializeSuccess:
                    return Alert(
                        title: Text("Operation Successful"),
                        message: Text("This week now matches your predefined transactions."),
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
            .alert("Couldn't Update the Week", isPresented: $showWeekError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(weekErrorMessage ?? "Something went wrong.")
            }
        }
    }

    private var weekRange: String {
        PerthWeek.label(for: PerthWeek.monday(containing: .now))
    }

    private var editingPresented: Binding<Bool> {
        Binding(
            get: { editingTransactionID != nil },
            set: { if !$0 { editingTransactionID = nil } }
        )
    }

    private var weekMenu: some View {
        Menu {
            Button(role: .destructive) {
                activeAlert = .reset
            } label: {
                Label("Reset Week", systemImage: "arrow.counterclockwise")
            }
            .accessibilityIdentifier("resetButton")

            Button {
                confirmInitialize()
            } label: {
                Label("Initialize Week", systemImage: "calendar.badge.plus")
            }
            .accessibilityIdentifier("initializeWeekButton")

            Button {
                showingImportSessions = true
            } label: {
                Label("Import Sessions", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("importSessionsButton")
        } label: {
            Label("Week", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("weekActionsMenu")
    }

    private var daySelector: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                let isSelected = selectedDay == day
                Button {
                    withAnimation(.snappy) { selectedDay = day }
                } label: {
                    VStack(spacing: 3) {
                        Text(String(day.prefix(3)))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Circle()
                            .fill(day == Weekday.today ? (isSelected ? Color.white : FinanceTheme.accent) : Color.clear)
                            .frame(width: 5, height: 5)
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .frame(maxWidth: .infinity, minHeight: chipMinHeight)
                    .background(
                        isSelected ? FinanceTheme.accent : FinanceTheme.surface,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day)
                .accessibilityValue(day == Weekday.today ? "Today" : "")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
    }

    private func transactionsForDay(_ day: String) -> [Transaction] {
        transactions.filter { $0.dayOfWeek == day && !$0.isCompleted && $0.deletedAt == nil }
    }

    private func resetAll() {
        Task { await resetWeekOnline() }
    }

    private func resetWeekOnline() async {
        do {
            try await FinanceCloud.shared.resetFinanceWeek(in: modelContext)
            activeAlert = .resetSuccess
        } catch {
            weekErrorMessage = error.localizedDescription
            showWeekError = true
        }
    }

    private func confirmInitialize() {
        do {
            let rows = try livePredefinedRows()
            guard !rows.isEmpty else {
                activeAlert = .noPredefinedTransactions
                return
            }
            let total = predefinedWeekBalance(rows, unscheduledDay: Weekday.today)
            activeAlert = .initializeWeek(total)
        } catch {
            weekErrorMessage = error.localizedDescription
            showWeekError = true
        }
    }

    private func initializeWeek() {
        do {
            let rows = try livePredefinedRows()
            guard !rows.isEmpty else {
                activeAlert = .noPredefinedTransactions
                return
            }
        } catch {
            weekErrorMessage = error.localizedDescription
            showWeekError = true
            return
        }
        Task { await initializeWeekOnline() }
    }

    private func livePredefinedRows() throws -> [PredefinedWeekRow] {
        try modelContext.fetch(FetchDescriptor<PredefinedTransaction>())
            .filter { $0.deletedAt == nil }
            .map {
                PredefinedWeekRow(
                    amount: $0.amount,
                    isIncome: $0.isIncome,
                    dayOfWeek: $0.dayOfWeek,
                    isDeleted: false
                )
            }
    }

    private func initializeWeekOnline() async {
        do {
            try await FinanceCloud.shared.reinitializeFinanceWeek(
                unscheduledDay: Weekday.today,
                in: modelContext
            )
            activeAlert = .initializeSuccess
        } catch {
            weekErrorMessage = error.localizedDescription
            showWeekError = true
        }
    }
}
