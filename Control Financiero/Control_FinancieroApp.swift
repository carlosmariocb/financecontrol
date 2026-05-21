import SwiftUI
import SwiftData

@main
struct Control_FinancieroApp: App {
    let sharedModelContainer: ModelContainer = {
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        try? SeedDefaults.seedIfEmpty(sharedModelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
