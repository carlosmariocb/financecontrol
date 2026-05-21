import Foundation
import SwiftData

@Model
final class CreditCard {
    @Attribute(.unique) var id: UUID
    var name: String
    var bank: String
    var cutOffDay: Int
    var paymentDueDay: Int
    var limitMinor: Int64?
    var currency: Currency
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        bank: String,
        cutOffDay: Int,
        paymentDueDay: Int,
        limitMinor: Int64? = nil,
        currency: Currency = .COP,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.bank = bank
        self.cutOffDay = cutOffDay
        self.paymentDueDay = paymentDueDay
        self.limitMinor = limitMinor
        self.currency = currency
        self.createdAt = createdAt
    }
}
