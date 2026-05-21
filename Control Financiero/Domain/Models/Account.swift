import Foundation
import SwiftData

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: AccountType
    var currency: Currency
    var initialBalanceMinor: Int64
    var includeInTotal: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        currency: Currency = .COP,
        initialBalanceMinor: Int64 = 0,
        includeInTotal: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.currency = currency
        self.initialBalanceMinor = initialBalanceMinor
        self.includeInTotal = includeInTotal
        self.createdAt = createdAt
    }
}
