import Foundation

nonisolated enum AccountType: String, Codable, CaseIterable, Sendable {
    case bank
    case wallet
    case cash
    case pocket
    case foreignWallet = "foreign_wallet"
}
