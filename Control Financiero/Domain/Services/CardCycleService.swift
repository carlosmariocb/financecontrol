import Foundation

/// Pure functions for credit-card billing-cycle math.
///
/// Card billing in Colombia (and most places): the statement *cuts* on `cutOffDay`
/// and is *due* on `paymentDueDay`. With our defaults `paymentDueDay < cutOffDay`,
/// each bill cut on month M is due in month M+1.
///
/// All functions are calendar-aware and clamp days to the actual length of the
/// target month — a cutoff of 31 lands on Feb 28 (or 29 in a leap year).
nonisolated enum CardCycleService {

    /// Most recent cutoff date on or before `today`.
    /// E.g. cutOffDay=25, today=May 20 → April 25 (last 25th that has already passed).
    static func lastCutoffDate(
        for card: CreditCard,
        asOf today: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date {
        mostRecentDayOfMonth(card.cutOffDay, onOrBefore: today, calendar: calendar)
    }

    /// Next payment-due date strictly on or after `today`.
    /// E.g. paymentDueDay=5, today=May 20 → June 5.
    static func nextPaymentDueDate(
        for card: CreditCard,
        asOf today: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date {
        nextDayOfMonth(card.paymentDueDay, onOrAfter: today, calendar: calendar)
    }

    /// Total of card purchases and fees charged to `card` in the *current* cycle —
    /// i.e. since the most recent cutoff, up through `today` inclusive. These charges
    /// will appear on the next statement.
    ///
    /// Payments are NOT subtracted here; this is statement spend, not net balance.
    /// Use `BalanceService.currentCardBalance` for net debt.
    static func currentCycleSpending(
        for card: CreditCard,
        transactions: [Transaction],
        asOf today: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Money {
        let cycleStart = lastCutoffDate(for: card, asOf: today, calendar: calendar)
        let minor = transactions.reduce(Int64(0)) { acc, tx in
            guard tx.creditCard?.id == card.id,
                  tx.date > cycleStart,
                  tx.date <= today,
                  isCardCharge(tx.type)
            else { return acc }
            return acc + tx.amountMinor
        }
        return Money(amountMinor: minor, currency: card.currency)
    }

    /// Whether a transaction type counts as a charge *on the card* (increases card debt).
    static func isCardCharge(_ type: TransactionType) -> Bool {
        switch type {
        case .creditCardPurchase, .feeOrInterest: true
        case .income, .expense, .transfer, .creditCardPayment, .savingsAllocation, .debtPayment: false
        }
    }

    // MARK: - Day-of-month helpers

    /// The most recent date on or before `reference` whose day-of-month is `day`,
    /// clamped to the last day of any month with fewer days. Comparisons are made
    /// at day granularity, so a same-day match counts as "on or before".
    static func mostRecentDayOfMonth(
        _ day: Int,
        onOrBefore reference: Date,
        calendar: Calendar
    ) -> Date {
        let refDay = calendar.startOfDay(for: reference)
        let candidateThisMonth = clampedDate(day: day, in: refDay, calendar: calendar)
        if candidateThisMonth <= refDay {
            return candidateThisMonth
        }
        let prev = calendar.date(byAdding: .month, value: -1, to: refDay) ?? refDay
        return clampedDate(day: day, in: prev, calendar: calendar)
    }

    /// The next date on or after `reference` whose day-of-month is `day`,
    /// clamped to the last day of any month with fewer days. Comparisons are made
    /// at day granularity, so a same-day match counts as "on or after".
    static func nextDayOfMonth(
        _ day: Int,
        onOrAfter reference: Date,
        calendar: Calendar
    ) -> Date {
        let refDay = calendar.startOfDay(for: reference)
        let candidateThisMonth = clampedDate(day: day, in: refDay, calendar: calendar)
        if candidateThisMonth >= refDay {
            return candidateThisMonth
        }
        let next = calendar.date(byAdding: .month, value: 1, to: refDay) ?? refDay
        return clampedDate(day: day, in: next, calendar: calendar)
    }

    /// Returns a date at the start of `day` in the month of `reference`, clamped to
    /// the last day of that month if `day` exceeds it.
    private static func clampedDate(day: Int, in reference: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month], from: reference)
        let monthLength = calendar.range(of: .day, in: .month, for: reference)?.count ?? 28
        components.day = min(max(day, 1), monthLength)
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? reference
    }
}
