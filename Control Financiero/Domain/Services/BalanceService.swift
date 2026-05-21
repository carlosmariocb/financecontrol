import Foundation
import SwiftData

/// Derives account balances and spending totals from Transactions.
/// Pure functions: no SwiftUI, no networking, no SwiftData fetches inside —
/// callers fetch the relevant collections (often via `@Query`) and pass them in.
nonisolated enum BalanceService {

    /// Current balance of `account` = its initial balance + the signed contribution
    /// of every Transaction that touches it.
    static func currentBalance(for account: Account, transactions: [Transaction]) -> Money {
        var minor = account.initialBalanceMinor
        for tx in transactions {
            minor += accountDelta(tx, for: account)
        }
        return Money(amountMinor: minor, currency: account.currency)
    }

    /// Sum of `currentBalance` across all accounts in `accounts` of the given currency
    /// that are flagged `includeInTotal`.
    static func totalBalance(
        currency: Currency,
        accounts: [Account],
        transactions: [Transaction]
    ) -> Money {
        let minor = accounts
            .filter { $0.includeInTotal && $0.currency == currency }
            .map { currentBalance(for: $0, transactions: transactions).amountMinor }
            .reduce(0, +)
        return Money(amountMinor: minor, currency: currency)
    }

    /// Current balance (outstanding debt) of `card` = signed sum of every Transaction
    /// that touches it: purchases and fees increase the balance, payments reduce it.
    /// A positive number means money owed.
    static func currentCardBalance(for card: CreditCard, transactions: [Transaction]) -> Money {
        var minor: Int64 = 0
        for tx in transactions {
            minor += cardDelta(tx, for: card)
        }
        return Money(amountMinor: minor, currency: card.currency)
    }

    /// Sum of `currentBalance` across "liquid" accounts (bank, wallet, cash) of the given
    /// currency. Pockets and foreign wallets are excluded.
    static func liquidBalance(
        currency: Currency,
        accounts: [Account],
        transactions: [Transaction]
    ) -> Money {
        let liquidTypes: Set<AccountType> = [.bank, .wallet, .cash]
        let minor = accounts
            .filter { liquidTypes.contains($0.type) && $0.currency == currency }
            .map { currentBalance(for: $0, transactions: transactions).amountMinor }
            .reduce(0, +)
        return Money(amountMinor: minor, currency: currency)
    }

    /// Total spending in `[from, to]`, restricted to `currency`. Excludes transfers,
    /// savings allocations, income, credit-card payments, and principal-only debt
    /// payments. Includes expenses, credit-card purchases (recognized on purchase
    /// date), and fees / interest.
    static func totalSpending(
        in transactions: [Transaction],
        from start: Date,
        to end: Date,
        currency: Currency
    ) -> Money {
        let minor = transactions.reduce(Int64(0)) { acc, tx in
            guard tx.includeInReports,
                  tx.currency == currency,
                  tx.date >= start,
                  tx.date <= end,
                  isSpending(type: tx.type)
            else { return acc }
            return acc + tx.amountMinor
        }
        return Money(amountMinor: minor, currency: currency)
    }

    /// Whether a TransactionType counts as outgoing spending for reports / budgets.
    static func isSpending(type: TransactionType) -> Bool {
        switch type {
        case .expense, .creditCardPurchase, .feeOrInterest:
            true
        case .income, .transfer, .creditCardPayment, .savingsAllocation, .debtPayment:
            false
        }
    }

    // MARK: - Private

    /// Signed minor-unit contribution of `tx` to `account`'s balance.
    private static func accountDelta(_ tx: Transaction, for account: Account) -> Int64 {
        let isSource = tx.account?.id == account.id
        let isDest = tx.toAccount?.id == account.id

        switch tx.type {
        case .income:
            return isSource ? tx.amountMinor : 0
        case .expense, .feeOrInterest, .debtPayment, .creditCardPayment:
            return isSource ? -tx.amountMinor : 0
        case .transfer, .savingsAllocation:
            if isSource { return -tx.amountMinor }
            if isDest { return tx.amountMinor }
            return 0
        case .creditCardPurchase:
            // Doesn't move the bank account — increases the card's balance instead.
            // See `cardDelta`.
            return 0
        }
    }

    /// Signed minor-unit contribution of `tx` to `card`'s outstanding balance.
    /// Purchases and fees charged to the card increase the debt; payments reduce it.
    private static func cardDelta(_ tx: Transaction, for card: CreditCard) -> Int64 {
        guard tx.creditCard?.id == card.id else { return 0 }
        switch tx.type {
        case .creditCardPurchase, .feeOrInterest:
            return tx.amountMinor
        case .creditCardPayment:
            return -tx.amountMinor
        case .income, .expense, .transfer, .savingsAllocation, .debtPayment:
            return 0
        }
    }
}
