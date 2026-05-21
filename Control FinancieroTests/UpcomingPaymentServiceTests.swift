import Foundation
import Testing
@testable import Control_Financiero

struct UpcomingPaymentServiceTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Bogota") ?? .current
        return cal
    }()

    @Test func billsAndDebtsAreReturnedInDueDateOrder() {
        let billLate = RecurringBill(name: "Internet", amountMinor: 100_000, dueDay: 25)
        let billEarly = RecurringBill(name: "Luz", amountMinor: 50_000, dueDay: 5)
        let debt = Debt(name: "Préstamo", originalAmountMinor: 1_000_000,
                        currentBalanceMinor: 500_000, paymentAmountMinor: 80_000, dueDay: 15)

        let today = day(2026, 5, 1)
        let result = UpcomingPaymentService.upcomingPayments(
            bills: [billLate, billEarly], debts: [debt], cards: [], transactions: [],
            asOf: today, calendar: calendar
        )

        #expect(result.count == 3)
        #expect(result.map(\.kind) == [.bill, .debt, .bill]) // by day: 5, 15, 25
        #expect(result.map(\.name) == ["Luz", "Préstamo", "Internet"])
    }

    @Test func inactiveBillsAreSkipped() {
        let bill = RecurringBill(name: "Gimnasio", amountMinor: 80_000, dueDay: 10, isActive: false)
        let today = day(2026, 5, 1)
        let result = UpcomingPaymentService.upcomingPayments(
            bills: [bill], debts: [], cards: [], transactions: [],
            asOf: today, calendar: calendar
        )
        #expect(result.isEmpty)
    }

    @Test func debtsWithNoOutstandingBalanceAreSkipped() {
        let paid = Debt(name: "Préstamo", originalAmountMinor: 1_000_000,
                        currentBalanceMinor: 0, paymentAmountMinor: 80_000, dueDay: 15)
        let today = day(2026, 5, 1)
        let result = UpcomingPaymentService.upcomingPayments(
            bills: [], debts: [paid], cards: [], transactions: [],
            asOf: today, calendar: calendar
        )
        #expect(result.isEmpty)
    }

    @Test func cardsAppearOnlyWhenTheyHaveActivity() {
        let card = CreditCard(name: "Lulo", bank: "Lulo", cutOffDay: 15, paymentDueDay: 5)
        let today = day(2026, 5, 20)

        let purchase = Transaction(
            date: day(2026, 5, 18), type: .creditCardPurchase,
            amountMinor: 320_000, currency: .COP, creditCard: card
        )

        let withSpend = UpcomingPaymentService.upcomingPayments(
            bills: [], debts: [], cards: [card], transactions: [purchase],
            asOf: today, calendar: calendar
        )
        #expect(withSpend.count == 1)
        #expect(withSpend.first?.kind == .card)
        #expect(withSpend.first?.amount.amountMinor == 320_000)

        let withoutSpend = UpcomingPaymentService.upcomingPayments(
            bills: [], debts: [], cards: [card], transactions: [],
            asOf: today, calendar: calendar
        )
        #expect(withoutSpend.isEmpty)
    }

    @Test func farFuturePaymentsAreOutsideHorizon() {
        // A bill due ~60 days out shouldn't appear with the default 35-day horizon.
        let bill = RecurringBill(name: "Anual", amountMinor: 1_000_000, dueDay: 1)
        let today = day(2026, 5, 1)  // next due day=1 → Jun 1 (within horizon)
        _ = bill  // unused in the simplified version below
        // Clear case: horizon=2, bill day=20 → next due is May 20 → outside [May 1, May 3]
        let bill2 = RecurringBill(name: "Lejos", amountMinor: 100, dueDay: 20)
        let result = UpcomingPaymentService.upcomingPayments(
            bills: [bill2], debts: [], cards: [], transactions: [],
            asOf: today, horizonDays: 2, calendar: calendar
        )
        #expect(result.isEmpty)
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 12
        return calendar.date(from: c)!
    }
}
