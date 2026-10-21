import Foundation
import SwiftData
import Testing
@testable import MyFinanceTracker

struct FinanceSyncTests {
    @Test func remoteNewerWins() {
        let older = Date(timeIntervalSince1970: 10)
        let newer = Date(timeIntervalSince1970: 20)
        #expect(cloudMergeAction(localUpdatedAt: older, lastSyncedAt: older, remoteUpdatedAt: newer) == .applyRemote)
    }

    @Test func localEditUploads() {
        let synced = Date(timeIntervalSince1970: 10)
        let edited = Date(timeIntervalSince1970: 20)
        #expect(cloudMergeAction(localUpdatedAt: edited, lastSyncedAt: synced, remoteUpdatedAt: synced) == .uploadLocal)
    }

    @Test func unchangedRowStays() {
        let stamp = Date(timeIntervalSince1970: 10)
        #expect(cloudMergeAction(localUpdatedAt: stamp, lastSyncedAt: stamp, remoteUpdatedAt: stamp) == .leave)
    }

    @Test func missingRemoteIsUploadedAgain() {
        let stamp = Date(timeIntervalSince1970: 10)
        #expect(cloudMergeAction(localUpdatedAt: stamp, lastSyncedAt: stamp, remoteUpdatedAt: nil) == .uploadLocal)
        #expect(cloudMergeAction(localUpdatedAt: stamp, lastSyncedAt: nil, remoteUpdatedAt: nil) == .uploadLocal)
    }

    @Test func firstUploadKeepsLocalWhenRemoteIsNotNewer() {
        let local = Date(timeIntervalSince1970: 20)
        let remote = Date(timeIntervalSince1970: 10)
        #expect(cloudMergeAction(localUpdatedAt: local, lastSyncedAt: nil, remoteUpdatedAt: remote) == .uploadLocal)
    }

    @Test func completingATransactionDoesNotChangeBalance() {
        let delta = transactionBalanceDelta(
            oldAmount: 40,
            oldIsIncome: true,
            oldIsDeleted: false,
            newAmount: 40,
            newIsIncome: true,
            newIsDeleted: false
        )
        #expect(delta == 0)
    }

    @Test func newExpenseAndDeletedIncomeAdjustBalance() {
        #expect(transactionBalanceContribution(amount: 19, isIncome: false, isDeleted: false) == -19)
        #expect(transactionBalanceContribution(amount: 19, isIncome: false, isDeleted: true) == 0)
        let deletedIncome = transactionBalanceDelta(
            oldAmount: 50,
            oldIsIncome: true,
            oldIsDeleted: false,
            newAmount: 50,
            newIsIncome: true,
            newIsDeleted: true
        )
        #expect(deletedIncome == -50)
    }

    @Test func tickingNeedsAConnectionBeforeAnyRequest() {
        #expect(shouldCompleteTransactionOnline(isSignedIn: false, isOnline: true) == false)
        #expect(shouldCompleteTransactionOnline(isSignedIn: true, isOnline: false) == false)
        #expect(shouldCompleteTransactionOnline(isSignedIn: true, isOnline: true))
        #expect(FinanceCloudError.needsConnection.errorDescription == "Ticking a transaction needs an internet connection.")
    }

    @Test func cancellingATickDoesNotCompleteTheTransaction() {
        #expect(shouldCompleteTransaction(for: .cancel) == false)
        #expect(shouldCompleteTransaction(for: .tick))
        #expect(shouldCompleteTransaction(for: .addToCashFlow))
    }

    @Test func initializeWeekBalanceMatchesPredefinedDays() {
        let rows = [
            PredefinedWeekRow(amount: 6, isIncome: false, dayOfWeek: "Every day"),
            PredefinedWeekRow(amount: 28, isIncome: false, dayOfWeek: "Monday"),
            PredefinedWeekRow(amount: 120, isIncome: true, dayOfWeek: "Wednesday"),
            PredefinedWeekRow(amount: 80, isIncome: false, dayOfWeek: "Friday"),
            PredefinedWeekRow(amount: 10, isIncome: true, dayOfWeek: nil),
            PredefinedWeekRow(amount: 99, isIncome: true, dayOfWeek: "Monday", isDeleted: true)
        ]
        // Every day −42, Monday −28, Wednesday +120, Friday −80, missing day +10. Deleted is ignored.
        #expect(predefinedWeekBalance(rows, unscheduledDay: "Wednesday") == -20)
    }

    @Test func initializeWeekBalanceIsTheSignedSumEvenWhenItIsZero() {
        let rows = [
            PredefinedWeekRow(amount: 10, isIncome: true, dayOfWeek: "Monday"),
            PredefinedWeekRow(amount: 10, isIncome: false, dayOfWeek: "Tuesday")
        ]
        #expect(predefinedWeekBalance(rows, unscheduledDay: "Monday") == 0)
    }

    @Test func initializeConfirmationUsesThePredefinedTotal() {
        let rows = [
            PredefinedWeekRow(amount: 6, isIncome: false, dayOfWeek: "Every day"),
            PredefinedWeekRow(amount: 28, isIncome: false, dayOfWeek: "Monday"),
            PredefinedWeekRow(amount: 120, isIncome: true, dayOfWeek: "Wednesday"),
            PredefinedWeekRow(amount: 80, isIncome: false, dayOfWeek: "Friday")
        ]
        let total = predefinedWeekBalance(rows, unscheduledDay: "Wednesday")
        #expect(total == -30)
        let message = initializeWeekConfirmationMessage(total: total)
        #expect(message.contains("replaces this week"))
        #expect(message.contains("predefined"))
        #expect(message.contains(total.formattedAsCurrency()))
        #expect(message.contains("$0.00") == false)
    }

    @Test func amountFieldsUseTwoDecimalPlaces() {
        #expect(80.0.amountFieldText() == "80.00")
        #expect(6.0.amountFieldText() == "6.00")
        #expect(80.5.amountFieldText() == "80.50")
    }

    @Test func completeRequestTicksWithoutCashFlow() throws {
        let id = try #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        let call = completeFinanceTransactionCall(
            transactionID: id,
            addToCashFlow: false,
            additionalCost: 0,
            splitNames: nil
        )
        #expect(call.httpMethod == "POST")
        #expect(call.path == "/rest/v1/rpc/complete_finance_transaction")
        let json = try jsonObject(from: completeFinanceTransactionBody(call))
        #expect(json["p_transaction_id"] as? String == "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        #expect(json["p_add_to_cash_flow"] as? Bool == false)
        #expect(json["p_additional_cost"] as? Double == 0)
        #expect(json["p_split_names"] is NSNull)
    }

    @Test func completeRequestSendsCourtCostAndUntrimmedNames() throws {
        let id = UUID()
        let call = completeFinanceTransactionCall(
            transactionID: id,
            addToCashFlow: true,
            additionalCost: 31,
            splitNames: ["Ann", " "]
        )
        let json = try jsonObject(from: completeFinanceTransactionBody(call))
        #expect(json["p_transaction_id"] as? String == id.uuidString.lowercased())
        #expect(json["p_add_to_cash_flow"] as? Bool == true)
        #expect((json["p_additional_cost"] as? NSNumber)?.doubleValue == 31)
        #expect(json["p_split_names"] as? [String] == ["Ann", " "])
    }

    @Test func timestampsRoundTripAndTrimMicroseconds() throws {
        let stamp = Date(timeIntervalSince1970: 1_700_000_000.123)
        let parsed = try #require(SupabaseTimestamp.parse(SupabaseTimestamp.format(stamp)))
        #expect(abs(parsed.timeIntervalSince(stamp)) < 0.001)
        let remote = try #require(SupabaseTimestamp.parse("2026-10-21T06:59:00.123456+00:00"))
        #expect(remote.timeIntervalSince1970 > 0)
    }

    @Test func schemaNamesMatchAcrossVersions() {
        let v1 = Set(Schema(versionedSchema: AppSchemaV1.self).entities.map(\.name))
        let v2 = Set(Schema(versionedSchema: AppSchemaV2.self).entities.map(\.name))
        let v3 = Set(Schema(versionedSchema: AppSchemaV3.self).entities.map(\.name))
        let v4 = Set(Schema(versionedSchema: AppSchemaV4.self).entities.map(\.name))
        #expect(v1 == [
            "CashFlowItem",
            "NetIncomeEntity",
            "PredefinedTransaction",
            "QuickAddTransaction",
            "Transaction"
        ])
        #expect(v1 == v2)
        #expect(v1 == v3)
        #expect(v4 == [
            "CashFlowItem",
            "NetIncomeEntity",
            "PredefinedTransaction",
            "Transaction"
        ])
        let v2Fields = transactionPropertyNames(AppSchemaV2.self)
        let v3Fields = transactionPropertyNames(AppSchemaV3.self)
        #expect(v2Fields.contains("coachingSessionID") == false)
        #expect(v2Fields.contains("coachingWeekStart") == false)
        #expect(v3Fields.contains("coachingSessionID"))
        #expect(v3Fields.contains("coachingWeekStart"))
    }

    @Test func lightweightMigrationKeepsExistingRows() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "finance-migration-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appending(path: "Finance.store")
        defer { try? FileManager.default.removeItem(at: directory) }

        let originalID = UUID()
        let cashID = UUID()
        let predefinedID = UUID()
        do {
            let schema = Schema(versionedSchema: AppSchemaV1.self)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: [ModelConfiguration(schema: schema, url: storeURL)]
            )
            let context = ModelContext(container)
            context.insert(AppSchemaV1.Transaction(
                id: originalID,
                desc: "Coaching",
                amount: 80,
                dayOfWeek: "Monday",
                isCompleted: false,
                isIncome: true
            ))
            context.insert(AppSchemaV1.NetIncomeEntity(value: 80))
            context.insert(AppSchemaV1.CashFlowItem(
                id: cashID,
                name: "Court",
                amount: 12,
                isOwedToMe: true,
                isSettled: false
            ))
            context.insert(AppSchemaV1.PredefinedTransaction(
                id: predefinedID,
                desc: "Rent",
                amount: 40,
                dayOfWeek: "Monday",
                isIncome: false
            ))
            context.insert(AppSchemaV1.QuickAddTransaction(
                id: UUID(),
                desc: "Coffee",
                amount: 5,
                isIncome: false
            ))
            try context.save()
        }

        let schema = Schema(versionedSchema: AppSchemaV4.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: AppMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: storeURL)]
        )
        let context = ModelContext(container)
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        #expect(transactions.count == 1)
        #expect(transactions[0].id == originalID)
        #expect(transactions[0].desc == "Coaching")
        #expect(transactions[0].amount == 80)
        #expect(transactions[0].isCompleted == false)
        #expect(transactions[0].deletedAt == nil)
        #expect(transactions[0].lastSyncedAt == nil)
        #expect(transactions[0].coachingSessionID == nil)
        #expect(transactions[0].coachingWeekStart == nil)

        let balances = try context.fetch(FetchDescriptor<NetIncomeEntity>())
        #expect(balances.count == 1)
        #expect(balances[0].value == 80)
        #expect(balances[0].deletedAt == nil)

        let cash = try context.fetch(FetchDescriptor<CashFlowItem>())
        #expect(cash.count == 1)
        #expect(cash[0].id == cashID)
        #expect(cash[0].name == "Court")
        #expect(cash[0].amount == 12)
        #expect(cash[0].isOwedToMe == true)
        #expect(cash[0].deletedAt == nil)

        let predefined = try context.fetch(FetchDescriptor<PredefinedTransaction>())
        #expect(predefined.count == 1)
        #expect(predefined[0].id == predefinedID)
        #expect(predefined[0].desc == "Rent")
        #expect(predefined[0].amount == 40)
        #expect(predefined[0].isIncome == false)
        #expect(Set(container.schema.entities.map(\.name)).contains("QuickAddTransaction") == false)
    }

    @Test func coachingLinkMigrationKeepsExistingRows() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "finance-v2-migration-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appending(path: "Finance.store")
        defer { try? FileManager.default.removeItem(at: directory) }

        let originalID = UUID()
        let synced = Date(timeIntervalSince1970: 1_700_000_000)
        do {
            let schema = Schema(versionedSchema: AppSchemaV2.self)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: [ModelConfiguration(schema: schema, url: storeURL)]
            )
            let context = ModelContext(container)
            context.insert(AppSchemaV2.Transaction(
                id: originalID,
                desc: "Coaching",
                amount: 80,
                dayOfWeek: "Monday",
                isCompleted: true,
                isIncome: true,
                updatedAt: synced,
                lastSyncedAt: synced
            ))
            context.insert(AppSchemaV2.QuickAddTransaction(
                id: UUID(),
                desc: "Coffee",
                amount: 5,
                isIncome: true,
                updatedAt: synced,
                lastSyncedAt: synced
            ))
            try context.save()
        }

        let schema = Schema(versionedSchema: AppSchemaV4.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: AppMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: storeURL)]
        )
        let context = ModelContext(container)
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        #expect(transactions.count == 1)
        #expect(transactions[0].id == originalID)
        #expect(transactions[0].amount == 80)
        #expect(transactions[0].isCompleted == true)
        #expect(transactions[0].updatedAt == synced)
        #expect(transactions[0].coachingSessionID == nil)
        #expect(transactions[0].coachingWeekStart == nil)
        #expect(Set(container.schema.entities.map(\.name)).contains("QuickAddTransaction") == false)
    }

    @Test func droppingQuickAddKeepsTheOtherRows() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "finance-v3-migration-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appending(path: "Finance.store")
        defer { try? FileManager.default.removeItem(at: directory) }

        let transactionID = UUID()
        let balanceID = UUID()
        let cashID = UUID()
        let predefinedID = UUID()
        let sessionID = UUID()
        let synced = Date(timeIntervalSince1970: 1_700_000_000)
        let week = Date(timeIntervalSince1970: 1_729_296_000)
        do {
            let schema = Schema(versionedSchema: AppSchemaV3.self)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: [ModelConfiguration(schema: schema, url: storeURL)]
            )
            let context = ModelContext(container)
            context.insert(Transaction(
                id: transactionID,
                desc: "Coaching",
                amount: 80,
                dayOfWeek: "Monday",
                isCompleted: true,
                isIncome: true,
                updatedAt: synced,
                lastSyncedAt: synced,
                coachingSessionID: sessionID,
                coachingWeekStart: week
            ))
            context.insert(NetIncomeEntity(
                id: balanceID,
                value: -520,
                updatedAt: synced,
                lastSyncedAt: synced
            ))
            context.insert(CashFlowItem(
                id: cashID,
                name: "Court",
                amount: 12,
                isOwedToMe: false,
                isSettled: true,
                updatedAt: synced,
                lastSyncedAt: synced
            ))
            context.insert(PredefinedTransaction(
                id: predefinedID,
                desc: "Rent",
                amount: 40,
                dayOfWeek: "Monday",
                isIncome: false,
                updatedAt: synced,
                lastSyncedAt: synced
            ))
            context.insert(AppSchemaV3.QuickAddTransaction(
                id: UUID(),
                desc: "Coffee",
                amount: 5,
                isIncome: true,
                updatedAt: synced,
                lastSyncedAt: synced
            ))
            try context.save()
        }

        let schema = Schema(versionedSchema: AppSchemaV4.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: AppMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: storeURL)]
        )
        let context = ModelContext(container)
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        #expect(transactions.count == 1)
        #expect(transactions[0].id == transactionID)
        #expect(transactions[0].amount == 80)
        #expect(transactions[0].isCompleted == true)
        #expect(transactions[0].updatedAt == synced)
        #expect(transactions[0].lastSyncedAt == synced)
        #expect(transactions[0].coachingSessionID == sessionID)
        #expect(transactions[0].coachingWeekStart == week)

        let balances = try context.fetch(FetchDescriptor<NetIncomeEntity>())
        #expect(balances.count == 1)
        #expect(balances[0].id == balanceID)
        #expect(balances[0].value == -520)
        #expect(balances[0].updatedAt == synced)

        let cash = try context.fetch(FetchDescriptor<CashFlowItem>())
        #expect(cash.count == 1)
        #expect(cash[0].id == cashID)
        #expect(cash[0].name == "Court")
        #expect(cash[0].isSettled == true)
        #expect(cash[0].updatedAt == synced)

        let predefined = try context.fetch(FetchDescriptor<PredefinedTransaction>())
        #expect(predefined.count == 1)
        #expect(predefined[0].id == predefinedID)
        #expect(predefined[0].desc == "Rent")
        #expect(predefined[0].updatedAt == synced)
        #expect(Set(container.schema.entities.map(\.name)).contains("QuickAddTransaction") == false)
    }

    @Test func offlineSyncStaysSilent() {
        let offline = URLError(.notConnectedToInternet)
        let first = nextFinanceSyncNotice(isSignedIn: true, error: offline, consecutiveFailures: 0, current: nil)
        #expect(first.notice == nil)
        #expect(first.consecutiveFailures == 0)

        let duringRetries = nextFinanceSyncNotice(isSignedIn: true, error: offline, consecutiveFailures: 2, current: nil)
        #expect(duringRetries.notice == nil)
        #expect(duringRetries.consecutiveFailures == 2)

        let kept = nextFinanceSyncNotice(
            isSignedIn: true,
            error: URLError(.timedOut),
            consecutiveFailures: 3,
            current: .uploadsNotSending
        )
        #expect(kept.notice == .uploadsNotSending)
        #expect(financeSyncPrompt(isSignedIn: true, notice: nil) == nil)
    }

    @Test func uploadFailuresPromptOnlyAfterTheyRepeat() {
        let error = FinanceCloudError.requestFailed("500")
        var failures = 0
        var notice: FinanceSyncNotice?
        for _ in 1...2 {
            let step = nextFinanceSyncNotice(
                isSignedIn: true,
                error: error,
                consecutiveFailures: failures,
                current: notice
            )
            failures = step.consecutiveFailures
            notice = step.notice
            #expect(notice == nil)
        }
        let third = nextFinanceSyncNotice(
            isSignedIn: true,
            error: error,
            consecutiveFailures: failures,
            current: notice
        )
        #expect(third.consecutiveFailures == 3)
        #expect(third.notice == .uploadsNotSending)
        #expect(financeSyncPrompt(isSignedIn: true, notice: third.notice) == .uploadsNotSending)

        let success = nextFinanceSyncNotice(
            isSignedIn: true,
            error: nil,
            consecutiveFailures: third.consecutiveFailures,
            current: third.notice
        )
        #expect(success.notice == nil)
        #expect(success.consecutiveFailures == 0)
        #expect(financeSyncPrompt(isSignedIn: true, notice: success.notice) == nil)
    }

    @Test func signedOutAndBlockedAccountPromptImmediately() {
        #expect(financeSyncPrompt(isSignedIn: false, notice: nil) == .signIn)
        let expired = nextFinanceSyncNotice(
            isSignedIn: true,
            error: FinanceCloudError.notSignedIn,
            consecutiveFailures: 4,
            current: .uploadsNotSending
        )
        #expect(expired.notice == .needsSignIn)
        #expect(expired.consecutiveFailures == 0)
        #expect(financeSyncPrompt(isSignedIn: true, notice: expired.notice) == .signIn)

        let signedOut = nextFinanceSyncNotice(
            isSignedIn: false,
            error: FinanceCloudError.notSignedIn,
            consecutiveFailures: 4,
            current: .uploadsNotSending
        )
        #expect(signedOut.notice == nil)
        #expect(financeSyncPrompt(isSignedIn: false, notice: signedOut.notice) == .signIn)

        let blocked = nextFinanceSyncNotice(
            isSignedIn: true,
            error: FinanceCloudError.workspaceUnavailable,
            consecutiveFailures: 0,
            current: nil
        )
        #expect(blocked.notice == .accountBlocked)
        #expect(financeSyncPrompt(isSignedIn: true, notice: blocked.notice) == .accountBlocked)

        let stillBlocked = nextFinanceSyncNotice(
            isSignedIn: true,
            error: FinanceCloudError.requestFailed("500"),
            consecutiveFailures: blocked.consecutiveFailures,
            current: blocked.notice
        )
        #expect(stillBlocked.notice == .accountBlocked)
    }

    @Test func importingNeedsAConnectionBeforeAnyRequest() {
        #expect(shouldImportSessionsOnline(isSignedIn: false, isOnline: true) == false)
        #expect(shouldImportSessionsOnline(isSignedIn: true, isOnline: false) == false)
        #expect(shouldImportSessionsOnline(isSignedIn: true, isOnline: true))
        #expect(FinanceCloudError.importNeedsConnection.errorDescription == "Importing sessions needs an internet connection.")
    }

    @Test func importRequestCoversTheShownWeek() throws {
        let monday = try perthDate(year: 2026, month: 10, day: 19)
        let preview = coachingSessionsPreviewCall(weekStart: monday)
        #expect(preview.httpMethod == "POST")
        #expect(preview.path == "/rest/v1/rpc/coaching_sessions_for_finance")
        let previewJSON = try jsonObject(from: coachingSessionsPreviewBody(preview))
        #expect(previewJSON["p_week_start"] as? String == "2026-10-19")

        let call = importCoachingSessionsCall(weekStart: monday, sessionIDs: nil)
        #expect(call.httpMethod == "POST")
        #expect(call.path == "/rest/v1/rpc/import_coaching_sessions_to_finance")
        let json = try jsonObject(from: importCoachingSessionsBody(call))
        #expect(json["p_week_start"] as? String == "2026-10-19")
        #expect(json["p_session_ids"] is NSNull)
    }

    @Test func dateOnlyRoundTripsAndPerthWeekStartsMonday() throws {
        let parsed = try #require(SupabaseTimestamp.parse("2026-10-19"))
        #expect(SupabaseTimestamp.formatDateOnly(parsed) == "2026-10-19")
        let wednesday = try perthDate(year: 2026, month: 10, day: 21, hour: 15)
        let monday = PerthWeek.monday(containing: wednesday)
        #expect(PerthWeek.dateOnlyString(from: monday) == "2026-10-19")
        let sunday = try perthDate(year: 2026, month: 10, day: 25, hour: 23)
        #expect(PerthWeek.dateOnlyString(from: PerthWeek.monday(containing: sunday)) == "2026-10-19")
        #expect(PerthWeek.dateOnlyString(from: PerthWeek.addingWeeks(1, to: monday)) == "2026-10-26")
    }

    @Test func defaultWeekStaysOrMovesForward() async throws {
        let monday = PerthWeek.monday(containing: try perthDate(year: 2026, month: 10, day: 21))
        var seen: [String] = []
        let current = await defaultCoachingWeekStart(currentMonday: monday) { week in
            let key = PerthWeek.dateOnlyString(from: week)
            seen.append(key)
            return key == "2026-10-19" ? ["live"] : []
        }
        #expect(seen == ["2026-10-19"])
        #expect(current.rows == ["live"])

        seen = []
        let upcoming = await defaultCoachingWeekStart(currentMonday: monday) { week in
            let key = PerthWeek.dateOnlyString(from: week)
            seen.append(key)
            return key == "2026-11-02" ? [1] : []
        }
        #expect(PerthWeek.dateOnlyString(from: upcoming.week) == "2026-11-02")
        #expect(seen == ["2026-10-19", "2026-10-26", "2026-11-02"])

        seen = []
        let none = await defaultCoachingWeekStart(currentMonday: monday, searchLimit: 2) { week in
            seen.append(PerthWeek.dateOnlyString(from: week))
            return [Int]()
        }
        #expect(PerthWeek.dateOnlyString(from: none.week) == "2026-10-19")
        #expect(seen == ["2026-10-19", "2026-10-26", "2026-11-02"])
    }

    @Test func uploadOmitsNilCoachingFields() throws {
        let id = try #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        let workspace = try #require(UUID(uuidString: "0DB2B4F5-FF7C-4FBD-B71B-E2DDF9D5DEF6"))
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let omitted = transactionUploadBody(
            id: id,
            workspaceID: workspace,
            description: "Coaching",
            amount: 80,
            dayOfWeek: "Monday",
            isCompleted: false,
            isIncome: true,
            updatedAt: stamp,
            deletedAt: nil,
            coachingSessionID: nil,
            coachingWeekStart: nil
        )
        let omittedJSON = try jsonObject(from: omitted)
        #expect(omittedJSON.keys.contains("coaching_session_id") == false)
        #expect(omittedJSON.keys.contains("coaching_week_start") == false)

        let week = try #require(SupabaseTimestamp.parse("2026-10-19"))
        let linked = transactionUploadBody(
            id: id,
            workspaceID: workspace,
            description: "Ann, Bob",
            amount: 80,
            dayOfWeek: "Monday",
            isCompleted: false,
            isIncome: true,
            updatedAt: stamp,
            deletedAt: nil,
            coachingSessionID: id,
            coachingWeekStart: week
        )
        let linkedJSON = try jsonObject(from: linked)
        #expect(linkedJSON["coaching_session_id"] as? String == "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        #expect(linkedJSON["coaching_week_start"] as? String == "2026-10-19")
    }

    @Test func previewMarksImportedSessionsAndSkipsThem() throws {
        let json = """
        [
          {
            "session_id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            "week_start": "2026-10-19",
            "day_of_week": "Monday",
            "session_name": "Ann, Bob",
            "session_fee": 80,
            "start_time": "2026-10-19T01:00:00+00:00",
            "already_imported": true
          },
          {
            "session_id": "BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            "week_start": "2026-10-19",
            "day_of_week": "Tuesday",
            "session_name": null,
            "session_fee": "0",
            "start_time": "2026-10-20T01:00:00+00:00",
            "already_imported": false
          },
          {
            "session_id": "CCCCCCCC-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            "week_start": "2026-10-19",
            "day_of_week": "Wednesday",
            "session_name": "Cara",
            "session_fee": 40,
            "start_time": "2026-10-21T01:00:00+00:00",
            "already_imported": false
          }
        ]
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = SupabaseTimestamp.parse(value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "bad date")
            }
            return date
        }
        let rows = try decoder.decode([CoachingSessionPreview].self, from: json)
        #expect(rows[0].alreadyImported)
        #expect(rows[0].sessionName == "Ann, Bob")
        #expect(SupabaseTimestamp.formatDateOnly(rows[0].weekStart) == "2026-10-19")
        #expect(rows[1].sessionName == "Coaching")
        #expect(rows[1].sessionFee == 0)
        let importable = importableCoachingSessions(rows)
        #expect(importable.map(\.sessionName) == ["Cara"])
        #expect(importSessionsSuccessMessage(added: 0) == "No new sessions were added.")
        #expect(importSessionsSuccessMessage(added: 1) == "Added 1 income transaction.")
        #expect(importSessionsSuccessMessage(added: 2) == "Added 2 income transactions.")
    }

    @Test func weekResetNeedsAConnectionBeforeAnyRequest() throws {
        #expect(shouldUpdateFinanceWeekOnline(isSignedIn: false, isOnline: true) == false)
        #expect(shouldUpdateFinanceWeekOnline(isSignedIn: true, isOnline: false) == false)
        #expect(shouldUpdateFinanceWeekOnline(isSignedIn: true, isOnline: true))
        #expect(FinanceCloudError.resetNeedsConnection.errorDescription == "Resetting the week needs an internet connection.")
        #expect(FinanceCloudError.initializeNeedsConnection.errorDescription == "Initializing the week needs an internet connection.")

        let reset = resetFinanceWeekCall()
        #expect(reset.httpMethod == "POST")
        #expect(reset.path == "/rest/v1/rpc/reset_finance_week")
        let resetJSON = try jsonObject(from: resetFinanceWeekBody())
        #expect(resetJSON.isEmpty)

        let call = reinitializeFinanceWeekCall(unscheduledDay: "Wednesday")
        #expect(call.httpMethod == "POST")
        #expect(call.path == "/rest/v1/rpc/reinitialize_finance_week")
        #expect(call.unscheduledDay == "Wednesday")
        let json = try jsonObject(from: reinitializeFinanceWeekBody(call))
        #expect(json["p_unscheduled_day"] as? String == "Wednesday")
    }

    @Test func resetPullKeepsTheServerBalance() {
        let synced = Date(timeIntervalSince1970: 100)
        let server = Date(timeIntervalSince1970: 200)
        let removed = transactionBalanceDelta(
            oldAmount: 150,
            oldIsIncome: true,
            oldIsDeleted: false,
            newAmount: 150,
            newIsIncome: true,
            newIsDeleted: true
        )
        #expect(removed == -150)
        let action = netIncomePullAction(
            localValue: 200,
            localUpdatedAt: synced,
            localLastSyncedAt: synced,
            serverValue: 0,
            serverUpdatedAt: server,
            transactionDelta: removed
        )
        #expect(action == .adoptServer(0))
    }

    @Test func initializePullKeepsTheServerBalance() {
        let synced = Date(timeIntervalSince1970: 100)
        let server = Date(timeIntervalSince1970: 200)
        let removed = transactionBalanceDelta(
            oldAmount: 100,
            oldIsIncome: true,
            oldIsDeleted: false,
            newAmount: 100,
            newIsIncome: true,
            newIsDeleted: true
        )
        let created = transactionBalanceContribution(amount: 520, isIncome: false, isDeleted: false)
        #expect(removed + created == -620)
        let action = netIncomePullAction(
            localValue: 40,
            localUpdatedAt: synced,
            localLastSyncedAt: synced,
            serverValue: -520,
            serverUpdatedAt: server,
            transactionDelta: removed + created
        )
        #expect(action == .adoptServer(-520))
    }

    @Test func secondInitializePullReplacesADriftedBalance() {
        let synced = Date(timeIntervalSince1970: 100)
        let server = Date(timeIntervalSince1970: 200)
        let action = netIncomePullAction(
            localValue: -500,
            localUpdatedAt: synced,
            localLastSyncedAt: synced,
            serverValue: -520,
            serverUpdatedAt: server,
            transactionDelta: 0
        )
        #expect(action == .adoptServer(-520))
    }

    @Test func importPullKeepsTheServerBalance() {
        let synced = Date(timeIntervalSince1970: 100)
        let server = Date(timeIntervalSince1970: 200)
        let added = transactionBalanceContribution(amount: 80, isIncome: true, isDeleted: false)
        #expect(added == 80)
        let drifted = netIncomePullAction(
            localValue: 150,
            localUpdatedAt: synced,
            localLastSyncedAt: synced,
            serverValue: 180,
            serverUpdatedAt: server,
            transactionDelta: added
        )
        #expect(drifted == .adoptServer(180))

        let matched = netIncomePullAction(
            localValue: 100,
            localUpdatedAt: synced,
            localLastSyncedAt: synced,
            serverValue: 180,
            serverUpdatedAt: server,
            transactionDelta: added
        )
        #expect(matched == .adoptServer(180))
    }

    @Test func tickPullLeavesTheBalanceUntouched() {
        let stamp = Date(timeIntervalSince1970: 100)
        let completion = transactionBalanceDelta(
            oldAmount: 40,
            oldIsIncome: true,
            oldIsDeleted: false,
            newAmount: 40,
            newIsIncome: true,
            newIsDeleted: false
        )
        #expect(completion == 0)
        let action = netIncomePullAction(
            localValue: 150,
            localUpdatedAt: stamp,
            localLastSyncedAt: stamp,
            serverValue: 150,
            serverUpdatedAt: stamp,
            transactionDelta: completion
        )
        #expect(action == .adjustLocal(value: 150, upload: false))
    }

    @Test func secondResetPullDoesNotUploadAnUnchangedZero() {
        let stamp = Date(timeIntervalSince1970: 100)
        let action = netIncomePullAction(
            localValue: 0,
            localUpdatedAt: stamp,
            localLastSyncedAt: stamp,
            serverValue: 0,
            serverUpdatedAt: stamp,
            transactionDelta: 0
        )
        #expect(action == .adjustLocal(value: 0, upload: false))
    }

    @Test func remoteTransactionWithoutANewerBalanceUploadsTheDelta() {
        let stamp = Date(timeIntervalSince1970: 100)
        let added = transactionBalanceContribution(amount: 40, isIncome: true, isDeleted: false)
        let unchangedRow = netIncomePullAction(
            localValue: 100,
            localUpdatedAt: stamp,
            localLastSyncedAt: stamp,
            serverValue: 100,
            serverUpdatedAt: stamp,
            transactionDelta: added
        )
        #expect(unchangedRow == .adjustLocal(value: 140, upload: true))

        let missingRow = netIncomePullAction(
            localValue: 100,
            localUpdatedAt: stamp,
            localLastSyncedAt: stamp,
            serverValue: nil,
            serverUpdatedAt: nil,
            transactionDelta: added
        )
        #expect(missingRow == .adjustLocal(value: 140, upload: true))
    }

    private func jsonObject(from body: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: body)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func transactionPropertyNames<Version: VersionedSchema>(_ version: Version.Type) -> Set<String> {
        let entity = Schema(versionedSchema: version).entities.first { $0.name == "Transaction" }
        return Set(entity?.properties.map { $0.name } ?? [])
    }

    private func perthDate(year: Int, month: Int, day: Int, hour: Int = 9) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Australia/Perth"))
        let parts = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        )
        return try #require(calendar.date(from: parts))
    }
}
