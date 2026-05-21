import Foundation
import SwiftData

@Model
final class Debt {
    @Attribute(.unique) var id: UUID
    var name: String
    var originalAmountMinor: Int64
    var currentBalanceMinor: Int64
    var currency: Currency
    var interestRate: Double?
    var paymentAmountMinor: Int64
    var dueDay: Int
    var reminderDaysBefore: Int

    init(
        id: UUID = UUID(),
        name: String,
        originalAmountMinor: Int64,
        currentBalanceMinor: Int64,
        currency: Currency = .COP,
        interestRate: Double? = nil,
        paymentAmountMinor: Int64 = 0,
        dueDay: Int = 1,
        reminderDaysBefore: Int = 3
    ) {
        self.id = id
        self.name = name
        self.originalAmountMinor = originalAmountMinor
        self.currentBalanceMinor = currentBalanceMinor
        self.currency = currency
        self.interestRate = interestRate
        self.paymentAmountMinor = paymentAmountMinor
        self.dueDay = dueDay
        self.reminderDaysBefore = reminderDaysBefore
    }
}
