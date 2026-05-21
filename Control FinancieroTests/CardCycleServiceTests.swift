import Foundation
import Testing
@testable import Control_Financiero

struct CardCycleServiceTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Bogota") ?? .current
        return cal
    }()

    // MARK: - lastCutoffDate

    @Test func lastCutoffIsInCurrentMonthWhenTodayIsPastCutoff() {
        let card = CreditCard(name: "Lulo", bank: "Lulo", cutOffDay: 15, paymentDueDay: 5)
        let today = date(2026, 5, 20)

        let cutoff = CardCycleService.lastCutoffDate(for: card, asOf: today, calendar: calendar)
        #expect(cutoff == date(2026, 5, 15))
    }

    @Test func lastCutoffRollsBackWhenTodayIsBeforeCutoff() {
        let card = CreditCard(name: "Davivienda", bank: "Davivienda", cutOffDay: 25, paymentDueDay: 15)
        let today = date(2026, 5, 20)

        let cutoff = CardCycleService.lastCutoffDate(for: card, asOf: today, calendar: calendar)
        #expect(cutoff == date(2026, 4, 25))
    }

    @Test func lastCutoffOnSameDayCountsAsToday() {
        let card = CreditCard(name: "Nu", bank: "Nu", cutOffDay: 20, paymentDueDay: 10)
        let today = date(2026, 5, 20)

        let cutoff = CardCycleService.lastCutoffDate(for: card, asOf: today, calendar: calendar)
        #expect(cutoff == date(2026, 5, 20))
    }

    @Test func lastCutoffClampsToShortMonth() {
        // cutoff=31, today=March 5 → previous cutoff falls on Feb 28 (2026 is not a leap year).
        let card = CreditCard(name: "X", bank: "X", cutOffDay: 31, paymentDueDay: 20)
        let today = date(2026, 3, 5)

        let cutoff = CardCycleService.lastCutoffDate(for: card, asOf: today, calendar: calendar)
        #expect(cutoff == date(2026, 2, 28))
    }

    // MARK: - nextPaymentDueDate

    @Test func nextDueIsInCurrentMonthWhenTodayIsBeforeDueDay() {
        let card = CreditCard(name: "Lulo", bank: "Lulo", cutOffDay: 15, paymentDueDay: 5)
        let today = date(2026, 5, 3)

        let due = CardCycleService.nextPaymentDueDate(for: card, asOf: today, calendar: calendar)
        #expect(due == date(2026, 5, 5))
    }

    @Test func nextDueRollsForwardWhenTodayIsPastDueDay() {
        let card = CreditCard(name: "Lulo", bank: "Lulo", cutOffDay: 15, paymentDueDay: 5)
        let today = date(2026, 5, 20)

        let due = CardCycleService.nextPaymentDueDate(for: card, asOf: today, calendar: calendar)
        #expect(due == date(2026, 6, 5))
    }

    @Test func nextDueClampsAcrossYearBoundary() {
        let card = CreditCard(name: "Lulo", bank: "Lulo", cutOffDay: 28, paymentDueDay: 18)
        let today = date(2026, 12, 25)

        let due = CardCycleService.nextPaymentDueDate(for: card, asOf: today, calendar: calendar)
        #expect(due == date(2027, 1, 18))
    }

    // MARK: - currentCycleSpending

    @Test func currentCyclePicksUpPurchasesSinceLastCutoff() {
        let card = CreditCard(name: "Lulo", bank: "Lulo", cutOffDay: 15, paymentDueDay: 5)
        let today = date(2026, 5, 20)

        let beforeCycle = Transaction(
            date: date(2026, 5, 10), type: .creditCardPurchase,
            amountMinor: 100_000, currency: .COP, creditCard: card
        )
        let onCutoff = Transaction(
            date: date(2026, 5, 15), type: .creditCardPurchase,
            amountMinor: 50_000, currency: .COP, creditCard: card
        )
        let insideCycle = Transaction(
            date: date(2026, 5, 18), type: .creditCardPurchase,
            amountMinor: 80_000, currency: .COP, creditCard: card
        )
        let afterToday = Transaction(
            date: date(2026, 5, 21), type: .creditCardPurchase,
            amountMinor: 999_000, currency: .COP, creditCard: card
        )

        let total = CardCycleService.currentCycleSpending(
            for: card,
            transactions: [beforeCycle, onCutoff, insideCycle, afterToday],
            asOf: today,
            calendar: calendar
        )
        #expect(total.amountMinor == 80_000)
    }

    @Test func currentCycleIgnoresPaymentsAndOtherCards() {
        let lulo = CreditCard(name: "Lulo", bank: "Lulo", cutOffDay: 15, paymentDueDay: 5)
        let nu = CreditCard(name: "Nu", bank: "Nu", cutOffDay: 20, paymentDueDay: 10)
        let today = date(2026, 5, 20)

        let purchase = Transaction(
            date: date(2026, 5, 18), type: .creditCardPurchase,
            amountMinor: 100_000, currency: .COP, creditCard: lulo
        )
        let paymentSameCard = Transaction(
            date: date(2026, 5, 19), type: .creditCardPayment,
            amountMinor: 90_000, currency: .COP, creditCard: lulo
        )
        let otherCardPurchase = Transaction(
            date: date(2026, 5, 18), type: .creditCardPurchase,
            amountMinor: 500_000, currency: .COP, creditCard: nu
        )

        let total = CardCycleService.currentCycleSpending(
            for: lulo,
            transactions: [purchase, paymentSameCard, otherCardPurchase],
            asOf: today,
            calendar: calendar
        )
        #expect(total.amountMinor == 100_000)
    }

    @Test func currentCycleIncludesFeesAndInterest() {
        let card = CreditCard(name: "Lulo", bank: "Lulo", cutOffDay: 15, paymentDueDay: 5)
        let today = date(2026, 5, 20)
        let fee = Transaction(
            date: date(2026, 5, 18), type: .feeOrInterest,
            amountMinor: 25_000, currency: .COP, creditCard: card
        )
        let total = CardCycleService.currentCycleSpending(
            for: card, transactions: [fee], asOf: today, calendar: calendar
        )
        #expect(total.amountMinor == 25_000)
    }

    // MARK: - Helpers

    /// Start-of-day in the test calendar's timezone. We compare against this directly
    /// because `CardCycleService` always returns dates at midnight.
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = 0; c.minute = 0; c.second = 0
        return calendar.date(from: c)!
    }
}
