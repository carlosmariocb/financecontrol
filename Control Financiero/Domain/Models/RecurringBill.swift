import Foundation
import SwiftData

@Model
final class RecurringBill {
    @Attribute(.unique) var id: UUID
    var name: String
    var amountMinor: Int64
    var currency: Currency
    var dueDay: Int
    var account: Account?
    var category: TransactionCategory?
    var isActive: Bool
    var reminderDaysBefore: Int

    init(
        id: UUID = UUID(),
        name: String,
        amountMinor: Int64,
        currency: Currency = .COP,
        dueDay: Int,
        account: Account? = nil,
        category: TransactionCategory? = nil,
        isActive: Bool = true,
        reminderDaysBefore: Int = 3
    ) {
        self.id = id
        self.name = name
        self.amountMinor = amountMinor
        self.currency = currency
        self.dueDay = dueDay
        self.account = account
        self.category = category
        self.isActive = isActive
        self.reminderDaysBefore = reminderDaysBefore
    }
}
