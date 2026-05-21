import Foundation
import SwiftData

@Model
final class InstallmentPlan {
    @Attribute(.unique) var id: UUID
    var totalAmountMinor: Int64
    var numberOfInstallments: Int
    var remainingInstallments: Int
    var monthlyAmountMinor: Int64
    var creditCard: CreditCard?
    var startDate: Date
    var currency: Currency

    init(
        id: UUID = UUID(),
        totalAmountMinor: Int64,
        numberOfInstallments: Int,
        remainingInstallments: Int,
        monthlyAmountMinor: Int64,
        creditCard: CreditCard? = nil,
        startDate: Date,
        currency: Currency = .COP
    ) {
        self.id = id
        self.totalAmountMinor = totalAmountMinor
        self.numberOfInstallments = numberOfInstallments
        self.remainingInstallments = remainingInstallments
        self.monthlyAmountMinor = monthlyAmountMinor
        self.creditCard = creditCard
        self.startDate = startDate
        self.currency = currency
    }
}
