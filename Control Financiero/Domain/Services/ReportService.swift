import Foundation

/// Pure aggregations for the Reportes tab's charts and category breakdown.
///
/// All amounts are pre-filtered to `currency` and to the spending types
/// (`BalanceService.isSpending`) — so transfers, savings, and card payments are
/// never counted, matching the M2/M3 reporting rules.
nonisolated enum ReportService {

    /// One spending bar on the daily-breakdown chart.
    struct DailySpending: Identifiable, Hashable, Sendable {
        let date: Date
        let amount: Money
        var id: Date { date }
    }

    /// One row in the spending-by-category list.
    struct CategorySpending: Identifiable, Hashable, Sendable {
        let categoryName: String
        let group: BudgetGroup
        let amount: Money
        var id: String { categoryName + group.rawValue }
    }

    // MARK: - Daily spending

    /// Returns one `DailySpending` per calendar day in `[start, end]` that has any
    /// spending. Days with zero spending are omitted; charts render gaps naturally.
    static func spendingByDay(
        in transactions: [Transaction],
        from start: Date,
        to end: Date,
        currency: Currency,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [DailySpending] {
        var bucket: [Date: Int64] = [:]
        for tx in transactions {
            guard tx.includeInReports,
                  tx.currency == currency,
                  tx.date >= start,
                  tx.date <= end,
                  BalanceService.isSpending(type: tx.type)
            else { continue }
            let day = calendar.startOfDay(for: tx.date)
            bucket[day, default: 0] += tx.amountMinor
        }
        return bucket
            .map { DailySpending(date: $0.key, amount: Money(amountMinor: $0.value, currency: currency)) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - By-category breakdown

    /// Returns spending grouped by *top-level* category. Subcategories roll up to
    /// their parent. Uncategorized spending is bucketed under "Sin categoría" in
    /// the `.excluded` group.
    static func spendingByCategory(
        in transactions: [Transaction],
        from start: Date,
        to end: Date,
        currency: Currency
    ) -> [CategorySpending] {
        struct Key: Hashable { let name: String; let group: BudgetGroup }
        var bucket: [Key: Int64] = [:]

        for tx in transactions {
            guard tx.includeInReports,
                  tx.currency == currency,
                  tx.date >= start,
                  tx.date <= end,
                  BalanceService.isSpending(type: tx.type)
            else { continue }

            // Roll subcategories up to their parent for the headline list.
            let parent = tx.category?.parent ?? tx.category
            let name = parent?.name ?? "Sin categoría"
            let group = parent?.budgetGroup
                ?? tx.subcategory?.budgetGroup
                ?? tx.category?.budgetGroup
                ?? .excluded
            bucket[Key(name: name, group: group), default: 0] += tx.amountMinor
        }

        return bucket
            .map { CategorySpending(categoryName: $0.key.name, group: $0.key.group, amount: Money(amountMinor: $0.value, currency: currency)) }
            .sorted { $0.amount.amountMinor > $1.amount.amountMinor }
    }
}
