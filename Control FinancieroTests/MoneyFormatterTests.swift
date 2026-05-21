import Testing
@testable import Control_Financiero

struct MoneyFormatterTests {
    @Test func copWithThousands() {
        #expect(MoneyFormatter.format(.cop(120_000)) == "$120.000")
    }

    @Test func copExactThousand() {
        #expect(MoneyFormatter.format(.cop(8_000)) == "$8.000")
    }

    @Test func copMillions() {
        #expect(MoneyFormatter.format(.cop(1_234_567)) == "$1.234.567")
    }

    @Test func copZero() {
        #expect(MoneyFormatter.format(.cop(0)) == "$0")
    }

    @Test func copNegative() {
        #expect(MoneyFormatter.format(.cop(-50_000)) == "-$50.000")
    }

    @Test func usdWithDollarsAndCents() {
        #expect(MoneyFormatter.format(.usd(cents: 123_456)) == "$1,234.56")
    }

    @Test func usdZero() {
        #expect(MoneyFormatter.format(.usd(cents: 0)) == "$0.00")
    }

    @Test func usdSubDollar() {
        #expect(MoneyFormatter.format(.usd(cents: 7)) == "$0.07")
    }

    @Test func usdNegative() {
        #expect(MoneyFormatter.format(.usd(cents: -125)) == "-$1.25")
    }
}
