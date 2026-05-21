import Foundation
import SwiftData

@Model
final class BudgetPeriod {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date
    var incomePlannedMinor: Int64
    var needsLimitMinor: Int64
    var wantsLimitMinor: Int64
    var savingsDebtLimitMinor: Int64
    var rolloverAmountMinor: Int64
    var currency: Currency

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        incomePlannedMinor: Int64 = 0,
        needsLimitMinor: Int64 = 0,
        wantsLimitMinor: Int64 = 0,
        savingsDebtLimitMinor: Int64 = 0,
        rolloverAmountMinor: Int64 = 0,
        currency: Currency = .COP
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.incomePlannedMinor = incomePlannedMinor
        self.needsLimitMinor = needsLimitMinor
        self.wantsLimitMinor = wantsLimitMinor
        self.savingsDebtLimitMinor = savingsDebtLimitMinor
        self.rolloverAmountMinor = rolloverAmountMinor
        self.currency = currency
    }
}
