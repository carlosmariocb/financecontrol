import Foundation
import SwiftData
import Testing
@testable import Control_Financiero

/// Round-trip tests for the JSON backup pipeline. Uses an in-memory ModelContainer
/// so the test runs without touching disk.
@MainActor
struct BackupServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Account.self, CreditCard.self, TransactionCategory.self,
            Transaction.self, InstallmentPlan.self, Goal.self,
            Debt.self, RecurringBill.self, BudgetPeriod.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func snapshotEncodesAndDecodesIdentically() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let lulo = Account(name: "Lulo", type: .bank, currency: .COP, initialBalanceMinor: 250_000)
        let card = CreditCard(name: "Lulo", bank: "Lulo", cutOffDay: 15, paymentDueDay: 5)
        let food = TransactionCategory(name: "Comida", budgetGroup: .needs)
        let tx = Transaction(
            date: .now, type: .expense, amountMinor: 30_000, currency: .COP,
            account: lulo, category: food, merchant: "Mercado X"
        )
        ctx.insert(lulo); ctx.insert(card); ctx.insert(food); ctx.insert(tx)
        try ctx.save()

        let snapshot = try BackupService.snapshot(from: ctx)
        let data = try BackupService.jsonData(from: snapshot)
        let decoded = try BackupService.snapshot(from: data)

        #expect(decoded.schemaVersion == BackupService.schemaVersion)
        #expect(decoded.accounts.count == 1)
        #expect(decoded.accounts.first?.name == "Lulo")
        #expect(decoded.transactions.count == 1)
        #expect(decoded.transactions.first?.amountMinor == 30_000)
        #expect(decoded.transactions.first?.accountID == lulo.id)
        #expect(decoded.transactions.first?.categoryID == food.id)
        #expect(decoded.categories.first?.budgetGroup == .needs)
    }

    @Test func restoreReplacesAllExistingData() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // Pre-existing data that should be wiped.
        ctx.insert(Account(name: "Vieja", type: .bank, initialBalanceMinor: 999_999))
        try ctx.save()

        // Build a snapshot containing different data.
        let lulo = Account(id: UUID(), name: "Nueva", type: .wallet, currency: .COP, initialBalanceMinor: 100_000)
        let cat = TransactionCategory(id: UUID(), name: "Restaurantes", budgetGroup: .wants)
        let snapshot = BackupService.Snapshot(
            schemaVersion: 1, exportedAt: .now,
            accounts: [AccountDTO(lulo)],
            cards: [],
            categories: [CategoryDTO(cat)],
            transactions: [],
            installmentPlans: [],
            goals: [],
            debts: [],
            bills: [],
            periods: []
        )

        try BackupService.restore(snapshot, into: ctx)

        let accounts = try ctx.fetch(FetchDescriptor<Account>())
        #expect(accounts.count == 1)
        #expect(accounts.first?.name == "Nueva")
        #expect(accounts.first?.type == .wallet)

        let categories = try ctx.fetch(FetchDescriptor<TransactionCategory>())
        #expect(categories.count == 1)
        #expect(categories.first?.budgetGroup == .wants)
    }

    @Test func restoreReconstructsTransactionRelationships() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let accID = UUID()
        let catID = UUID()
        let txID = UUID()
        let acc = Account(id: accID, name: "Lulo", type: .bank, initialBalanceMinor: 0)
        let cat = TransactionCategory(id: catID, name: "Comida", budgetGroup: .needs)
        let tx = Transaction(
            id: txID, date: .now, type: .expense,
            amountMinor: 25_000, currency: .COP,
            account: acc, category: cat
        )

        let snapshot = BackupService.Snapshot(
            schemaVersion: 1, exportedAt: .now,
            accounts: [AccountDTO(acc)],
            cards: [],
            categories: [CategoryDTO(cat)],
            transactions: [TransactionDTO(tx)],
            installmentPlans: [],
            goals: [],
            debts: [],
            bills: [],
            periods: []
        )

        try BackupService.restore(snapshot, into: ctx)

        let restoredTxs = try ctx.fetch(FetchDescriptor<Transaction>())
        #expect(restoredTxs.count == 1)
        #expect(restoredTxs.first?.id == txID)
        #expect(restoredTxs.first?.account?.id == accID)
        #expect(restoredTxs.first?.category?.id == catID)
    }
}
