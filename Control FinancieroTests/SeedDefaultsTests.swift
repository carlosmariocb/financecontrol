import Foundation
import Testing
import SwiftData
@testable import Control_Financiero

struct SeedDefaultsTests {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            Account.self,
            CreditCard.self,
            TransactionCategory.self,
            Transaction.self,
            InstallmentPlan.self,
            Goal.self,
            Debt.self,
            RecurringBill.self,
            BudgetPeriod.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test func seedsExpectedDefaults() throws {
        let context = try makeInMemoryContext()
        try SeedDefaults.seedIfEmpty(context)

        let accountCount = try context.fetchCount(FetchDescriptor<Account>())
        let cardCount = try context.fetchCount(FetchDescriptor<CreditCard>())
        let goalCount = try context.fetchCount(FetchDescriptor<Goal>())
        let topLevelCategoryCount = try context.fetchCount(
            FetchDescriptor<TransactionCategory>(predicate: #Predicate { $0.parent == nil })
        )

        #expect(accountCount == 5)
        #expect(cardCount == 4)
        #expect(goalCount == 4)
        #expect(topLevelCategoryCount == 12)
    }

    @Test func seedingIsIdempotent() throws {
        let context = try makeInMemoryContext()
        try SeedDefaults.seedIfEmpty(context)
        try SeedDefaults.seedIfEmpty(context)

        let accountCount = try context.fetchCount(FetchDescriptor<Account>())
        let cardCount = try context.fetchCount(FetchDescriptor<CreditCard>())
        let goalCount = try context.fetchCount(FetchDescriptor<Goal>())

        #expect(accountCount == 5)
        #expect(cardCount == 4)
        #expect(goalCount == 4)
    }
}
