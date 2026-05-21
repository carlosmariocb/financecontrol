import Foundation

nonisolated enum BudgetGroup: String, Codable, CaseIterable, Sendable {
    case needs
    case wants
    case savingsDebt = "savings_debt"
    case excluded
}
