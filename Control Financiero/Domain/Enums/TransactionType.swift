import Foundation

nonisolated enum TransactionType: String, Codable, CaseIterable, Sendable {
    case income
    case expense
    case transfer
    case creditCardPurchase = "credit_card_purchase"
    case creditCardPayment = "credit_card_payment"
    case savingsAllocation = "savings_allocation"
    case debtPayment = "debt_payment"
    case feeOrInterest = "fee_or_interest"
}
