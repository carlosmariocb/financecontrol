import Foundation
import SwiftData

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var date: Date
    var type: TransactionType
    var amountMinor: Int64
    var currency: Currency
    var account: Account?
    var toAccount: Account?
    var creditCard: CreditCard?
    var category: TransactionCategory?
    var subcategory: TransactionCategory?
    var merchant: String?
    var details: String?
    var paymentChannel: String?
    var installmentPlan: InstallmentPlan?
    var goal: Goal?
    var debt: Debt?
    var includeInBudget: Bool
    var includeInReports: Bool
    var source: TransactionSource
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        type: TransactionType,
        amountMinor: Int64,
        currency: Currency,
        account: Account? = nil,
        toAccount: Account? = nil,
        creditCard: CreditCard? = nil,
        category: TransactionCategory? = nil,
        subcategory: TransactionCategory? = nil,
        merchant: String? = nil,
        details: String? = nil,
        paymentChannel: String? = nil,
        installmentPlan: InstallmentPlan? = nil,
        goal: Goal? = nil,
        debt: Debt? = nil,
        includeInBudget: Bool = true,
        includeInReports: Bool = true,
        source: TransactionSource = .manual,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.amountMinor = amountMinor
        self.currency = currency
        self.account = account
        self.toAccount = toAccount
        self.creditCard = creditCard
        self.category = category
        self.subcategory = subcategory
        self.merchant = merchant
        self.details = details
        self.paymentChannel = paymentChannel
        self.installmentPlan = installmentPlan
        self.goal = goal
        self.debt = debt
        self.includeInBudget = includeInBudget
        self.includeInReports = includeInReports
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
