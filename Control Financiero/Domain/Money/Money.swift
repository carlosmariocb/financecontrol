import Foundation

nonisolated struct Money: Codable, Hashable, Sendable {
    let amountMinor: Int64
    let currency: Currency

    static func cop(_ pesos: Int) -> Money {
        Money(amountMinor: Int64(pesos), currency: .COP)
    }

    static func usd(cents: Int) -> Money {
        Money(amountMinor: Int64(cents), currency: .USD)
    }

    static func zero(in currency: Currency) -> Money {
        Money(amountMinor: 0, currency: currency)
    }

    static func + (lhs: Money, rhs: Money) -> Money? {
        guard lhs.currency == rhs.currency else { return nil }
        return Money(amountMinor: lhs.amountMinor + rhs.amountMinor, currency: lhs.currency)
    }

    static func - (lhs: Money, rhs: Money) -> Money? {
        guard lhs.currency == rhs.currency else { return nil }
        return Money(amountMinor: lhs.amountMinor - rhs.amountMinor, currency: lhs.currency)
    }
}
