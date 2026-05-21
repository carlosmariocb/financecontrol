import Foundation

/// One-line summary of an obligation the user owes in the near future. Sourced from
/// recurring bills, debts, and credit-card statements — unified into a single sortable
/// type so the UI can render a mixed list without branching.
nonisolated struct UpcomingPayment: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case bill
        case debt
        case card
    }

    let id: UUID
    let kind: Kind
    let name: String
    let amount: Money
    let dueDate: Date
    let reminderDaysBefore: Int

    /// Whether the due date is in the past — drives the "Vencido" badge.
    func isOverdue(asOf today: Date) -> Bool {
        dueDate < today
    }
}

/// Pure aggregation of all upcoming financial obligations within a horizon.
///
/// Returns items sorted by `dueDate` ascending. The list does not include income
/// or savings goals — only money the user must hand over.
nonisolated enum UpcomingPaymentService {

    /// Returns all upcoming payments within `[today − pastDays, today + horizonDays]`.
    /// The slight backward window surfaces just-overdue items so the user sees them
    /// instead of having them silently disappear.
    static func upcomingPayments(
        bills: [RecurringBill],
        debts: [Debt],
        cards: [CreditCard],
        transactions: [Transaction],
        asOf today: Date = .now,
        pastDays: Int = 5,
        horizonDays: Int = 35,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [UpcomingPayment] {
        let lower = calendar.date(byAdding: .day, value: -pastDays, to: today) ?? today
        let upper = calendar.date(byAdding: .day, value: horizonDays, to: today) ?? today

        var items: [UpcomingPayment] = []

        for bill in bills where bill.isActive {
            let due = CardCycleService.nextDayOfMonth(bill.dueDay, onOrAfter: lower, calendar: calendar)
            if due >= lower && due <= upper {
                items.append(UpcomingPayment(
                    id: bill.id, kind: .bill, name: bill.name,
                    amount: Money(amountMinor: bill.amountMinor, currency: bill.currency),
                    dueDate: due, reminderDaysBefore: bill.reminderDaysBefore
                ))
            }
        }

        for debt in debts where debt.currentBalanceMinor > 0 && debt.paymentAmountMinor > 0 {
            let due = CardCycleService.nextDayOfMonth(debt.dueDay, onOrAfter: lower, calendar: calendar)
            if due >= lower && due <= upper {
                items.append(UpcomingPayment(
                    id: debt.id, kind: .debt, name: debt.name,
                    amount: Money(amountMinor: debt.paymentAmountMinor, currency: debt.currency),
                    dueDate: due, reminderDaysBefore: debt.reminderDaysBefore
                ))
            }
        }

        for card in cards {
            let due = CardCycleService.nextPaymentDueDate(for: card, asOf: today, calendar: calendar)
            guard due >= lower && due <= upper else { continue }
            // Use the current cycle's spending as a forward-looking estimate. If the
            // user has already made payments, current-card-balance is more accurate
            // for the "amount you must hand over by `due`" framing — take the max
            // of the two so a partially-paid huge bill still shows correctly.
            let balance = BalanceService.currentCardBalance(for: card, transactions: transactions)
            let cycle = CardCycleService.currentCycleSpending(for: card, transactions: transactions, asOf: today, calendar: calendar)
            let estimateMinor = max(balance.amountMinor, cycle.amountMinor)
            guard estimateMinor > 0 else { continue }
            items.append(UpcomingPayment(
                id: card.id, kind: .card, name: card.name,
                amount: Money(amountMinor: estimateMinor, currency: card.currency),
                dueDate: due, reminderDaysBefore: 3
            ))
        }

        return items.sorted { $0.dueDate < $1.dueDate }
    }
}
