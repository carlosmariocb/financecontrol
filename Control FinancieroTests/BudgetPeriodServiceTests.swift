import Foundation
import Testing
@testable import Control_Financiero

struct BudgetPeriodServiceTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Bogota") ?? .current
        return cal
    }()

    // MARK: - quincenalWindow

    @Test func firstHalfStartsOn1stEndsOn15th() {
        let date = day(2026, 5, 7)
        let (start, end) = BudgetPeriodService.quincenalWindow(containing: date, calendar: calendar)
        #expect(calendar.component(.day, from: start) == 1)
        #expect(calendar.component(.day, from: end) == 15)
        #expect(calendar.component(.month, from: start) == 5)
        #expect(calendar.component(.month, from: end) == 5)
    }

    @Test func fifteenthBelongsToFirstHalf() {
        let date = day(2026, 5, 15)
        let (start, end) = BudgetPeriodService.quincenalWindow(containing: date, calendar: calendar)
        #expect(calendar.component(.day, from: start) == 1)
        #expect(calendar.component(.day, from: end) == 15)
    }

    @Test func sixteenthBelongsToSecondHalf() {
        let date = day(2026, 5, 16)
        let (start, end) = BudgetPeriodService.quincenalWindow(containing: date, calendar: calendar)
        #expect(calendar.component(.day, from: start) == 16)
        #expect(calendar.component(.day, from: end) == 31) // May has 31 days
    }

    @Test func secondHalfEndsOnLastDayOfMonth() {
        // February 2026 has 28 days (not a leap year).
        let date = day(2026, 2, 20)
        let (start, end) = BudgetPeriodService.quincenalWindow(containing: date, calendar: calendar)
        #expect(calendar.component(.day, from: start) == 16)
        #expect(calendar.component(.day, from: end) == 28)
        #expect(calendar.component(.month, from: end) == 2)
    }

    @Test func windowEndIsInclusiveOfLastInstant() {
        // A transaction at 23:00 on the 15th should fall inside the first half.
        let date = day(2026, 5, 10)
        let (_, end) = BudgetPeriodService.quincenalWindow(containing: date, calendar: calendar)
        let lateOnFifteenth = dateTime(2026, 5, 15, 23, 0)
        #expect(lateOnFifteenth <= end)
    }

    // MARK: - budgetGroup resolution

    @Test func incomeTransferAndCardPaymentDoNotCountForBudget() {
        let income = Transaction(date: day(2026, 5, 5), type: .income, amountMinor: 1_000_000, currency: .COP)
        let transfer = Transaction(date: day(2026, 5, 5), type: .transfer, amountMinor: 1_000, currency: .COP)
        let cardPay = Transaction(date: day(2026, 5, 5), type: .creditCardPayment, amountMinor: 1_000, currency: .COP)

        #expect(BudgetPeriodService.budgetGroup(for: income) == nil)
        #expect(BudgetPeriodService.budgetGroup(for: transfer) == nil)
        #expect(BudgetPeriodService.budgetGroup(for: cardPay) == nil)
    }

    @Test func savingsAllocationAlwaysCountsAsSavingsDebt() {
        // Even with a category in `.wants`, savings allocations are SavingsDebt.
        let wantsCat = TransactionCategory(name: "Restaurantes", budgetGroup: .wants)
        let tx = Transaction(
            date: day(2026, 5, 5), type: .savingsAllocation, amountMinor: 100_000, currency: .COP,
            category: wantsCat
        )
        #expect(BudgetPeriodService.budgetGroup(for: tx) == .savingsDebt)
    }

    @Test func expenseInheritsBudgetGroupFromSubcategoryFirst() {
        let parent = TransactionCategory(name: "Comida", budgetGroup: .needs)
        let sub = TransactionCategory(name: "Restaurantes", budgetGroup: .wants, parent: parent)
        let tx = Transaction(
            date: day(2026, 5, 5), type: .expense, amountMinor: 50_000, currency: .COP,
            category: parent, subcategory: sub
        )
        #expect(BudgetPeriodService.budgetGroup(for: tx) == .wants)
    }

    @Test func uncategorizedExpenseIsExcluded() {
        let tx = Transaction(date: day(2026, 5, 5), type: .expense, amountMinor: 10_000, currency: .COP)
        #expect(BudgetPeriodService.budgetGroup(for: tx) == .excluded)
    }

    // MARK: - spendingByGroup

    @Test func spendingByGroupSumsAcrossNeedsWantsSavings() {
        let needsCat = TransactionCategory(name: "Mercado", budgetGroup: .needs)
        let wantsCat = TransactionCategory(name: "Restaurantes", budgetGroup: .wants)
        let txs = [
            Transaction(date: day(2026, 5, 3), type: .expense, amountMinor: 100_000, currency: .COP, category: needsCat),
            Transaction(date: day(2026, 5, 4), type: .expense, amountMinor: 50_000, currency: .COP, category: needsCat),
            Transaction(date: day(2026, 5, 5), type: .expense, amountMinor: 80_000, currency: .COP, category: wantsCat),
            Transaction(date: day(2026, 5, 6), type: .savingsAllocation, amountMinor: 300_000, currency: .COP),
            // out of period:
            Transaction(date: day(2026, 4, 30), type: .expense, amountMinor: 999_000, currency: .COP, category: needsCat),
            // wrong currency:
            Transaction(date: day(2026, 5, 7), type: .expense, amountMinor: 9_999, currency: .USD, category: needsCat),
        ]

        let (start, end) = BudgetPeriodService.quincenalWindow(containing: day(2026, 5, 5), calendar: calendar)
        let grouped = BudgetPeriodService.spendingByGroup(in: txs, from: start, to: end, currency: .COP)

        #expect(grouped.needs.amountMinor == 150_000)
        #expect(grouped.wants.amountMinor == 80_000)
        #expect(grouped.savingsDebt.amountMinor == 300_000)
        #expect(grouped.excluded.amountMinor == 0)
    }

    @Test func transfersAndCardPaymentsAreNotInAnyBucket() {
        let needsCat = TransactionCategory(name: "Mercado", budgetGroup: .needs)
        let txs = [
            Transaction(date: day(2026, 5, 5), type: .expense, amountMinor: 100_000, currency: .COP, category: needsCat),
            Transaction(date: day(2026, 5, 6), type: .transfer, amountMinor: 500_000, currency: .COP),
            Transaction(date: day(2026, 5, 7), type: .creditCardPayment, amountMinor: 200_000, currency: .COP),
        ]
        let (start, end) = BudgetPeriodService.quincenalWindow(containing: day(2026, 5, 5), calendar: calendar)
        let grouped = BudgetPeriodService.spendingByGroup(in: txs, from: start, to: end, currency: .COP)

        #expect(grouped.needs.amountMinor == 100_000)
        #expect(grouped.wants.amountMinor == 0)
        #expect(grouped.savingsDebt.amountMinor == 0)
        #expect(grouped.excluded.amountMinor == 0)
    }

    // MARK: - safeToSpend

    @Test func safeToSpendIsLimitMinusSpentOnNeedsAndWants() {
        let period = BudgetPeriod(
            startDate: day(2026, 5, 1), endDate: day(2026, 5, 15),
            needsLimitMinor: 1_000_000, wantsLimitMinor: 600_000, savingsDebtLimitMinor: 400_000
        )
        let needsCat = TransactionCategory(name: "Mercado", budgetGroup: .needs)
        let wantsCat = TransactionCategory(name: "Restaurantes", budgetGroup: .wants)
        let txs = [
            Transaction(date: day(2026, 5, 3), type: .expense, amountMinor: 300_000, currency: .COP, category: needsCat),
            Transaction(date: day(2026, 5, 8), type: .expense, amountMinor: 100_000, currency: .COP, category: wantsCat),
            // savings doesn't affect safe-to-spend
            Transaction(date: day(2026, 5, 10), type: .savingsAllocation, amountMinor: 400_000, currency: .COP),
        ]
        let safe = BudgetPeriodService.safeToSpend(period: period, transactions: txs)
        // (1_000_000 + 600_000) - (300_000 + 100_000) = 1_200_000
        #expect(safe.amountMinor == 1_200_000)
    }

    @Test func safeToSpendNeverGoesNegative() {
        let period = BudgetPeriod(
            startDate: day(2026, 5, 1), endDate: day(2026, 5, 15),
            needsLimitMinor: 100_000, wantsLimitMinor: 50_000
        )
        let cat = TransactionCategory(name: "Mercado", budgetGroup: .needs)
        let txs = [
            Transaction(date: day(2026, 5, 2), type: .expense, amountMinor: 500_000, currency: .COP, category: cat),
        ]
        let safe = BudgetPeriodService.safeToSpend(period: period, transactions: txs)
        #expect(safe.amountMinor == 0)
    }

    @Test func safeToSpendIncludesRollover() {
        let period = BudgetPeriod(
            startDate: day(2026, 5, 1), endDate: day(2026, 5, 15),
            needsLimitMinor: 1_000_000, wantsLimitMinor: 500_000,
            rolloverAmountMinor: 200_000
        )
        let safe = BudgetPeriodService.safeToSpend(period: period, transactions: [])
        #expect(safe.amountMinor == 1_700_000)
    }

    // MARK: - 50/30/20 split

    @Test func splitHonorsRoundingByPushingRemainderIntoSavings() {
        let (n, w, s) = BudgetPeriodService.split50_30_20(incomeMinor: 1_000_001)
        #expect(n == 500_000)            // 50%
        #expect(w == 300_000)            // 30%
        #expect(s == 200_001)            // remainder
        #expect(n + w + s == 1_000_001)
    }

    @Test func splitHandlesZero() {
        let (n, w, s) = BudgetPeriodService.split50_30_20(incomeMinor: 0)
        #expect(n == 0 && w == 0 && s == 0)
    }

    // MARK: - Helpers

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = 12   // midday — well inside the [start, end] window in any TZ.
        return calendar.date(from: c)!
    }

    private func dateTime(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = hour; c.minute = minute
        return calendar.date(from: c)!
    }
}
