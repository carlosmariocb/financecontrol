import Foundation

/// Pure functions for the quincenal budget model.
///
/// Periods follow the standard Colombian payroll cadence:
///   • First half:  1st 00:00:00 → 15th 23:59:59.999
///   • Second half: 16th 00:00:00 → last day of month 23:59:59.999
///
/// Transactions are bucketed into a `BudgetGroup` per the rules below; the
/// per-group totals drive the 50/30/20 progress bars and `safeToSpend`.
nonisolated enum BudgetPeriodService {

    /// Spending totals for one period, partitioned by `BudgetGroup`.
    struct GroupedSpending: Equatable, Sendable {
        let needs: Money
        let wants: Money
        let savingsDebt: Money
        let excluded: Money

        static func zero(in currency: Currency) -> GroupedSpending {
            GroupedSpending(
                needs: Money.zero(in: currency),
                wants: Money.zero(in: currency),
                savingsDebt: Money.zero(in: currency),
                excluded: Money.zero(in: currency)
            )
        }
    }

    // MARK: - Period boundaries

    /// (start, end] window of the quincenal period containing `date`. End is the
    /// last instant of the half (≈ 23:59:59.999 on day 15 or last day of month),
    /// so date comparisons via `<=` correctly include same-day transactions.
    static func quincenalWindow(
        containing date: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> (start: Date, end: Date) {
        let day = calendar.component(.day, from: date)
        let startOfMonth = startOfMonth(for: date, calendar: calendar)
        if day <= 15 {
            let start = startOfMonth
            let end = endOfDay(addingDays: 14, to: start, calendar: calendar) // day 15
            return (start, end)
        } else {
            let start = calendar.date(byAdding: .day, value: 15, to: startOfMonth) ?? startOfMonth // day 16
            let end = endOfMonth(for: date, calendar: calendar)
            return (start, end)
        }
    }

    private static func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    private static func endOfDay(addingDays days: Int, to start: Date, calendar: Calendar) -> Date {
        let dayStart = calendar.date(byAdding: .day, value: days, to: start) ?? start
        return endOfDay(of: dayStart, calendar: calendar)
    }

    private static func endOfDay(of date: Date, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = 23
        comps.minute = 59
        comps.second = 59
        comps.nanosecond = 999_000_000
        return calendar.date(from: comps) ?? date
    }

    private static func endOfMonth(for date: Date, calendar: Calendar) -> Date {
        let startOfThisMonth = startOfMonth(for: date, calendar: calendar)
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfThisMonth) ?? startOfThisMonth
        let lastDay = calendar.date(byAdding: .day, value: -1, to: startOfNextMonth) ?? startOfThisMonth
        return endOfDay(of: lastDay, calendar: calendar)
    }

    // MARK: - Group bucketing

    /// Determines which `BudgetGroup` a transaction contributes to — or `nil` if
    /// it doesn't count toward the budget at all (income, transfers, card payments).
    ///
    /// `savingsAllocation` and `debtPayment` always belong to `.savingsDebt`,
    /// regardless of category. Other spending types defer to the subcategory's
    /// group (or category's, or `.excluded` if uncategorized).
    static func budgetGroup(for tx: Transaction) -> BudgetGroup? {
        switch tx.type {
        case .income, .transfer, .creditCardPayment:
            return nil
        case .savingsAllocation, .debtPayment:
            return .savingsDebt
        case .expense, .creditCardPurchase, .feeOrInterest:
            return tx.subcategory?.budgetGroup
                ?? tx.category?.budgetGroup
                ?? .excluded
        }
    }

    /// Sums spending by `BudgetGroup` for transactions in `[start, end]` and matching
    /// `currency`. Uncategorized spending falls into `.excluded`.
    static func spendingByGroup(
        in transactions: [Transaction],
        from start: Date,
        to end: Date,
        currency: Currency
    ) -> GroupedSpending {
        var needs: Int64 = 0
        var wants: Int64 = 0
        var savings: Int64 = 0
        var excluded: Int64 = 0

        for tx in transactions {
            guard tx.currency == currency,
                  tx.date >= start,
                  tx.date <= end,
                  let group = budgetGroup(for: tx)
            else { continue }
            switch group {
            case .needs: needs += tx.amountMinor
            case .wants: wants += tx.amountMinor
            case .savingsDebt: savings += tx.amountMinor
            case .excluded: excluded += tx.amountMinor
            }
        }
        return GroupedSpending(
            needs: Money(amountMinor: needs, currency: currency),
            wants: Money(amountMinor: wants, currency: currency),
            savingsDebt: Money(amountMinor: savings, currency: currency),
            excluded: Money(amountMinor: excluded, currency: currency)
        )
    }

    /// Convenience overload that pulls the window from the `BudgetPeriod`.
    static func spendingByGroup(
        in period: BudgetPeriod,
        transactions: [Transaction]
    ) -> GroupedSpending {
        spendingByGroup(
            in: transactions,
            from: period.startDate,
            to: period.endDate,
            currency: period.currency
        )
    }

    // MARK: - Safe-to-spend

    /// Discretionary + essential budget remaining for the period:
    /// `max(0, (needsLimit + wantsLimit) − (needsSpent + wantsSpent))`.
    ///
    /// Savings/debt and excluded buckets are deliberately not subtracted: the user
    /// already earmarks money for those separately, and we don't want a planned
    /// savings deposit to make the safe-to-spend figure swing wildly.
    static func safeToSpend(
        period: BudgetPeriod,
        transactions: [Transaction]
    ) -> Money {
        let spending = spendingByGroup(in: period, transactions: transactions)
        let limit = period.needsLimitMinor + period.wantsLimitMinor + period.rolloverAmountMinor
        let spent = spending.needs.amountMinor + spending.wants.amountMinor
        let remaining = max(0, limit - spent)
        return Money(amountMinor: remaining, currency: period.currency)
    }

    // MARK: - 50/30/20 helper

    /// Default 50/30/20 split of an income amount, in minor units.
    /// Caller decides whether to apply this (e.g. via a button in the editor).
    static func split50_30_20(incomeMinor: Int64) -> (needs: Int64, wants: Int64, savings: Int64) {
        let needs = incomeMinor / 2                  // 50%
        let wants = (incomeMinor * 3) / 10           // 30%
        let savings = incomeMinor - needs - wants    // remainder ≈ 20%, absorbs rounding
        return (needs, wants, savings)
    }
}
