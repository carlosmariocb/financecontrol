import Foundation
import SwiftData

/// JSON snapshot of the full store. SwiftData `@Model` classes are not directly
/// Codable, so we round-trip via DTO structs that preserve UUIDs (so relationships
/// can be reconstructed by id) and use minor-unit integers for all money.
///
/// Backups are versioned (`schemaVersion`) to give us a chance to migrate
/// older payloads in the future. Restore is destructive: it wipes the current
/// store then inserts the snapshot. The caller is expected to confirm with the user.
@MainActor
enum BackupService {

    static let schemaVersion = 1

    // MARK: - Snapshot

    struct Snapshot: Codable {
        let schemaVersion: Int
        let exportedAt: Date
        let accounts: [AccountDTO]
        let cards: [CreditCardDTO]
        let categories: [CategoryDTO]
        let transactions: [TransactionDTO]
        let installmentPlans: [InstallmentPlanDTO]
        let goals: [GoalDTO]
        let debts: [DebtDTO]
        let bills: [RecurringBillDTO]
        let periods: [BudgetPeriodDTO]
    }

    // MARK: - Export

    static func snapshot(from context: ModelContext) throws -> Snapshot {
        let accounts: [Account] = try context.fetch(FetchDescriptor<Account>())
        let cards: [CreditCard] = try context.fetch(FetchDescriptor<CreditCard>())
        let categories: [TransactionCategory] = try context.fetch(FetchDescriptor<TransactionCategory>())
        let txs: [Transaction] = try context.fetch(FetchDescriptor<Transaction>())
        let plans: [InstallmentPlan] = try context.fetch(FetchDescriptor<InstallmentPlan>())
        let goals: [Goal] = try context.fetch(FetchDescriptor<Goal>())
        let debts: [Debt] = try context.fetch(FetchDescriptor<Debt>())
        let bills: [RecurringBill] = try context.fetch(FetchDescriptor<RecurringBill>())
        let periods: [BudgetPeriod] = try context.fetch(FetchDescriptor<BudgetPeriod>())

        return Snapshot(
            schemaVersion: schemaVersion,
            exportedAt: .now,
            accounts: accounts.map(AccountDTO.init),
            cards: cards.map(CreditCardDTO.init),
            categories: categories.map(CategoryDTO.init),
            transactions: txs.map(TransactionDTO.init),
            installmentPlans: plans.map(InstallmentPlanDTO.init),
            goals: goals.map(GoalDTO.init),
            debts: debts.map(DebtDTO.init),
            bills: bills.map(RecurringBillDTO.init),
            periods: periods.map(BudgetPeriodDTO.init)
        )
    }

    static func jsonData(from snapshot: Snapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    // MARK: - Import / restore

    static func snapshot(from data: Data) throws -> Snapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Snapshot.self, from: data)
    }

    /// Destructive restore: deletes every existing model object, then inserts the
    /// snapshot's contents and reconstructs cross-references by UUID.
    static func restore(_ snapshot: Snapshot, into context: ModelContext) throws {
        try deleteAll(in: context)

        // Insert top-level entities first so referenced objects exist by the time
        // we wire up the foreign-key relationships below.
        var accountByID: [UUID: Account] = [:]
        for dto in snapshot.accounts {
            let model = dto.toModel()
            context.insert(model)
            accountByID[model.id] = model
        }

        var cardByID: [UUID: CreditCard] = [:]
        for dto in snapshot.cards {
            let model = dto.toModel()
            context.insert(model)
            cardByID[model.id] = model
        }

        var categoryByID: [UUID: TransactionCategory] = [:]
        for dto in snapshot.categories {
            let model = TransactionCategory(id: dto.id, name: dto.name, budgetGroup: dto.budgetGroup)
            context.insert(model)
            categoryByID[model.id] = model
        }
        // Second pass to wire parent links once all categories exist.
        for dto in snapshot.categories {
            if let parentID = dto.parentID, let parent = categoryByID[parentID] {
                categoryByID[dto.id]?.parent = parent
            }
        }

        var planByID: [UUID: InstallmentPlan] = [:]
        for dto in snapshot.installmentPlans {
            let plan = InstallmentPlan(
                id: dto.id,
                totalAmountMinor: dto.totalAmountMinor,
                numberOfInstallments: dto.numberOfInstallments,
                remainingInstallments: dto.remainingInstallments,
                monthlyAmountMinor: dto.monthlyAmountMinor,
                creditCard: dto.creditCardID.flatMap { cardByID[$0] },
                startDate: dto.startDate,
                currency: dto.currency
            )
            context.insert(plan)
            planByID[plan.id] = plan
        }

        for dto in snapshot.transactions {
            let tx = Transaction(
                id: dto.id,
                date: dto.date,
                type: dto.type,
                amountMinor: dto.amountMinor,
                currency: dto.currency,
                account: dto.accountID.flatMap { accountByID[$0] },
                toAccount: dto.toAccountID.flatMap { accountByID[$0] },
                creditCard: dto.creditCardID.flatMap { cardByID[$0] },
                category: dto.categoryID.flatMap { categoryByID[$0] },
                subcategory: dto.subcategoryID.flatMap { categoryByID[$0] },
                merchant: dto.merchant,
                details: dto.details,
                paymentChannel: dto.paymentChannel,
                installmentPlan: dto.installmentPlanID.flatMap { planByID[$0] },
                includeInBudget: dto.includeInBudget,
                includeInReports: dto.includeInReports,
                source: dto.source,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt
            )
            context.insert(tx)
        }

        for dto in snapshot.goals {
            let goal = Goal(
                id: dto.id, name: dto.name,
                targetAmountMinor: dto.targetAmountMinor, currency: dto.currency,
                deadline: dto.deadline,
                linkedAccount: dto.linkedAccountID.flatMap { accountByID[$0] },
                createdAt: dto.createdAt
            )
            context.insert(goal)
        }

        for dto in snapshot.debts {
            let debt = Debt(
                id: dto.id, name: dto.name,
                originalAmountMinor: dto.originalAmountMinor,
                currentBalanceMinor: dto.currentBalanceMinor,
                currency: dto.currency,
                interestRate: dto.interestRate,
                paymentAmountMinor: dto.paymentAmountMinor,
                dueDay: dto.dueDay,
                reminderDaysBefore: dto.reminderDaysBefore
            )
            context.insert(debt)
        }

        for dto in snapshot.bills {
            let bill = RecurringBill(
                id: dto.id, name: dto.name,
                amountMinor: dto.amountMinor, currency: dto.currency,
                dueDay: dto.dueDay,
                account: dto.accountID.flatMap { accountByID[$0] },
                category: dto.categoryID.flatMap { categoryByID[$0] },
                isActive: dto.isActive,
                reminderDaysBefore: dto.reminderDaysBefore
            )
            context.insert(bill)
        }

        for dto in snapshot.periods {
            let period = BudgetPeriod(
                id: dto.id,
                startDate: dto.startDate, endDate: dto.endDate,
                incomePlannedMinor: dto.incomePlannedMinor,
                needsLimitMinor: dto.needsLimitMinor,
                wantsLimitMinor: dto.wantsLimitMinor,
                savingsDebtLimitMinor: dto.savingsDebtLimitMinor,
                rolloverAmountMinor: dto.rolloverAmountMinor,
                currency: dto.currency
            )
            context.insert(period)
        }

        try context.save()
    }

    private static func deleteAll(in context: ModelContext) throws {
        // Order matters: delete transactions before the entities they reference, so
        // SwiftData's cascading-relationship cleanup never sees a dangling pointer.
        try context.delete(model: Transaction.self)
        try context.delete(model: InstallmentPlan.self)
        try context.delete(model: BudgetPeriod.self)
        try context.delete(model: RecurringBill.self)
        try context.delete(model: Debt.self)
        try context.delete(model: Goal.self)
        try context.delete(model: TransactionCategory.self)
        try context.delete(model: CreditCard.self)
        try context.delete(model: Account.self)
        try context.save()
    }
}

// MARK: - DTOs

// One per @Model. UUIDs are preserved verbatim so relationships round-trip exactly.

struct AccountDTO: Codable {
    let id: UUID
    let name: String
    let type: AccountType
    let currency: Currency
    let initialBalanceMinor: Int64
    let includeInTotal: Bool
    let createdAt: Date

    init(_ a: Account) {
        id = a.id; name = a.name; type = a.type; currency = a.currency
        initialBalanceMinor = a.initialBalanceMinor
        includeInTotal = a.includeInTotal
        createdAt = a.createdAt
    }
    func toModel() -> Account {
        Account(id: id, name: name, type: type, currency: currency,
                initialBalanceMinor: initialBalanceMinor,
                includeInTotal: includeInTotal, createdAt: createdAt)
    }
}

struct CreditCardDTO: Codable {
    let id: UUID
    let name: String
    let bank: String
    let cutOffDay: Int
    let paymentDueDay: Int
    let limitMinor: Int64?
    let currency: Currency
    let createdAt: Date

    init(_ c: CreditCard) {
        id = c.id; name = c.name; bank = c.bank
        cutOffDay = c.cutOffDay; paymentDueDay = c.paymentDueDay
        limitMinor = c.limitMinor; currency = c.currency
        createdAt = c.createdAt
    }
    func toModel() -> CreditCard {
        CreditCard(id: id, name: name, bank: bank,
                   cutOffDay: cutOffDay, paymentDueDay: paymentDueDay,
                   limitMinor: limitMinor, currency: currency,
                   createdAt: createdAt)
    }
}

struct CategoryDTO: Codable {
    let id: UUID
    let name: String
    let budgetGroup: BudgetGroup
    let parentID: UUID?

    init(_ c: TransactionCategory) {
        id = c.id; name = c.name; budgetGroup = c.budgetGroup
        parentID = c.parent?.id
    }
}

struct TransactionDTO: Codable {
    let id: UUID
    let date: Date
    let type: TransactionType
    let amountMinor: Int64
    let currency: Currency
    let accountID: UUID?
    let toAccountID: UUID?
    let creditCardID: UUID?
    let categoryID: UUID?
    let subcategoryID: UUID?
    let merchant: String?
    let details: String?
    let paymentChannel: String?
    let installmentPlanID: UUID?
    let includeInBudget: Bool
    let includeInReports: Bool
    let source: TransactionSource
    let createdAt: Date
    let updatedAt: Date

    init(_ t: Transaction) {
        id = t.id; date = t.date; type = t.type
        amountMinor = t.amountMinor; currency = t.currency
        accountID = t.account?.id; toAccountID = t.toAccount?.id
        creditCardID = t.creditCard?.id
        categoryID = t.category?.id; subcategoryID = t.subcategory?.id
        merchant = t.merchant; details = t.details; paymentChannel = t.paymentChannel
        installmentPlanID = t.installmentPlan?.id
        includeInBudget = t.includeInBudget; includeInReports = t.includeInReports
        source = t.source; createdAt = t.createdAt; updatedAt = t.updatedAt
    }
}

struct InstallmentPlanDTO: Codable {
    let id: UUID
    let totalAmountMinor: Int64
    let numberOfInstallments: Int
    let remainingInstallments: Int
    let monthlyAmountMinor: Int64
    let creditCardID: UUID?
    let startDate: Date
    let currency: Currency

    init(_ p: InstallmentPlan) {
        id = p.id
        totalAmountMinor = p.totalAmountMinor
        numberOfInstallments = p.numberOfInstallments
        remainingInstallments = p.remainingInstallments
        monthlyAmountMinor = p.monthlyAmountMinor
        creditCardID = p.creditCard?.id
        startDate = p.startDate
        currency = p.currency
    }
}

struct GoalDTO: Codable {
    let id: UUID
    let name: String
    let targetAmountMinor: Int64
    let currency: Currency
    let deadline: Date?
    let linkedAccountID: UUID?
    let createdAt: Date

    init(_ g: Goal) {
        id = g.id; name = g.name
        targetAmountMinor = g.targetAmountMinor; currency = g.currency
        deadline = g.deadline; linkedAccountID = g.linkedAccount?.id
        createdAt = g.createdAt
    }
}

struct DebtDTO: Codable {
    let id: UUID
    let name: String
    let originalAmountMinor: Int64
    let currentBalanceMinor: Int64
    let currency: Currency
    let interestRate: Double?
    let paymentAmountMinor: Int64
    let dueDay: Int
    let reminderDaysBefore: Int

    init(_ d: Debt) {
        id = d.id; name = d.name
        originalAmountMinor = d.originalAmountMinor
        currentBalanceMinor = d.currentBalanceMinor
        currency = d.currency
        interestRate = d.interestRate
        paymentAmountMinor = d.paymentAmountMinor
        dueDay = d.dueDay; reminderDaysBefore = d.reminderDaysBefore
    }
}

struct RecurringBillDTO: Codable {
    let id: UUID
    let name: String
    let amountMinor: Int64
    let currency: Currency
    let dueDay: Int
    let accountID: UUID?
    let categoryID: UUID?
    let isActive: Bool
    let reminderDaysBefore: Int

    init(_ b: RecurringBill) {
        id = b.id; name = b.name
        amountMinor = b.amountMinor; currency = b.currency
        dueDay = b.dueDay
        accountID = b.account?.id; categoryID = b.category?.id
        isActive = b.isActive; reminderDaysBefore = b.reminderDaysBefore
    }
}

struct BudgetPeriodDTO: Codable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let incomePlannedMinor: Int64
    let needsLimitMinor: Int64
    let wantsLimitMinor: Int64
    let savingsDebtLimitMinor: Int64
    let rolloverAmountMinor: Int64
    let currency: Currency

    init(_ p: BudgetPeriod) {
        id = p.id; startDate = p.startDate; endDate = p.endDate
        incomePlannedMinor = p.incomePlannedMinor
        needsLimitMinor = p.needsLimitMinor
        wantsLimitMinor = p.wantsLimitMinor
        savingsDebtLimitMinor = p.savingsDebtLimitMinor
        rolloverAmountMinor = p.rolloverAmountMinor
        currency = p.currency
    }
}
