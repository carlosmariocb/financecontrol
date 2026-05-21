import Testing
@testable import Control_Financiero

struct MoneyTests {
    @Test func additionWithSameCurrency() {
        let result = Money.cop(100) + Money.cop(50)
        #expect(result == Money.cop(150))
    }

    @Test func subtractionWithSameCurrency() {
        let result = Money.cop(100) - Money.cop(30)
        #expect(result == Money.cop(70))
    }

    @Test func additionAcrossCurrenciesReturnsNil() {
        let result = Money.cop(100) + Money.usd(cents: 50)
        #expect(result == nil)
    }

    @Test func subtractionAcrossCurrenciesReturnsNil() {
        let result = Money.cop(100) - Money.usd(cents: 50)
        #expect(result == nil)
    }

    @Test func equalityRespectsCurrency() {
        let copHundred = Money.cop(100)
        let usdHundredMinor = Money(amountMinor: 100, currency: .USD)
        #expect(copHundred != usdHundredMinor)
    }

    @Test func zeroIsZero() {
        #expect(Money.zero(in: .COP).amountMinor == 0)
        #expect(Money.zero(in: .USD).amountMinor == 0)
    }
}
