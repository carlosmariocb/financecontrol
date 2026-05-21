import Foundation
import SwiftData

@Model
final class Goal {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetAmountMinor: Int64
    var currency: Currency
    var deadline: Date?
    var linkedAccount: Account?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        targetAmountMinor: Int64 = 0,
        currency: Currency = .COP,
        deadline: Date? = nil,
        linkedAccount: Account? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.targetAmountMinor = targetAmountMinor
        self.currency = currency
        self.deadline = deadline
        self.linkedAccount = linkedAccount
        self.createdAt = createdAt
    }
}
