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
        #expect(v1 == [
            "CashFlowItem",
            "NetIncomeEntity",
            "PredefinedTransaction",
            "QuickAddTransaction",
            "Transaction"
        ])
        #expect(v1 == v2)
    }

    @Test func lightweightMigrationKeepsExistingRows() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "finance-migration-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appending(path: "Finance.store")
        defer { try? FileManager.default.removeItem(at: directory) }

        let originalID = UUID()
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
            try context.save()
        }

        let schema = Schema(versionedSchema: AppSchemaV2.self)
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

        let balances = try context.fetch(FetchDescriptor<NetIncomeEntity>())
        #expect(balances.count == 1)
        #expect(balances[0].value == 80)
        #expect(balances[0].deletedAt == nil)
    }
}
