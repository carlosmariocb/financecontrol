import Foundation
import Testing
@testable import Control_Financiero

struct BalanceServiceTests {

    // MARK: - Income / expense

    @Test func incomeIncreasesAccountBalance() {
        let lulo = Account(name: "Lulo", type: .bank, initialBalanceMinor: 0)
        let salary = Transaction(
            date: .now, type: .income, amountMinor: 3_000_000, currency: .COP,
            account: lulo
        )

        let balance = BalanceService.currentBalance(for: lulo, transactions: [salary])
        #expect(balance.amountMinor == 3_000_000)
        #expect(balance.currency == .COP)
    }

    @Test func expenseDecreasesAccountBalance() {
        let nequi = Account(name: "Nequi", type: .wallet, initialBalanceMinor: 500_000)
        let coffee = Transaction(
            date: .now, type: .expense, amountMinor: 8_000, currency: .COP,
            account: nequi
        )

        let balance = BalanceService.currentBalance(for: nequi, transactions: [coffee])
        #expect(balance.amountMinor == 492_000)
    }

    @Test func expenseAppearsInSpendingTotal() {
        let nequi = Account(name: "Nequi", type: .wallet, initialBalanceMinor: 0)
        let coffee = Transaction(date: .now, type: .expense, amountMinor: 8_000, currency: .COP, account: nequi)
        let market = Transaction(date: .now, type: .expense, amountMinor: 50_000, currency: .COP, account: nequi)

        let (from, to) = dayWindow(around: .now)
        let spending = BalanceService.totalSpending(in: [coffee, market], from: from, to: to, currency: .COP)
        #expect(spending.amountMinor == 58_000)
    }

    // MARK: - Transfers

    @Test func transferChangesBothBalances() {
        let lulo = Account(name: "Lulo", type: .bank, initialBalanceMinor: 1_000_000)
        let nequi = Account(name: "Nequi", type: .wallet, initialBalanceMinor: 0)
        let tx = Transaction(
            date: .now, type: .transfer, amountMinor: 500_000, currency: .COP,
            account: lulo, toAccount: nequi
        )

        #expect(BalanceService.currentBalance(for: lulo, transactions: [tx]).amountMinor == 500_000)
        #expect(BalanceService.currentBalance(for: nequi, transactions: [tx]).amountMinor == 500_000)
    }

    @Test func transferIsNotSpending() {
        #expect(BalanceService.isSpending(type: .transfer) == false)
    }

    @Test func cashWithdrawalIsTransferNotExpense() {
        let lulo = Account(name: "Lulo", type: .bank, initialBalanceMinor: 200_000)
        let cash = Account(name: "Efectivo", type: .cash, initialBalanceMinor: 0)
        let tx = Transaction(
            date: .now, type: .transfer, amountMinor: 100_000, currency: .COP,
            account: lulo, toAccount: cash
        )

        let (from, to) = dayWindow(around: .now)
        let spending = BalanceService.totalSpending(in: [tx], from: from, to: to, currency: .COP)

        #expect(spending.amountMinor == 0)
        #expect(BalanceService.currentBalance(for: lulo, transactions: [tx]).amountMinor == 100_000)
        #expect(BalanceService.currentBalance(for: cash, transactions: [tx]).amountMinor == 100_000)
    }

    // MARK: - Credit card balance

    @Test func cardPurchaseIncreasesCardDebt() {
        let card = CreditCard(name: "Lulo", bank: "Lulo", cutOffDay: 15, paymentDueDay: 5)
        let tx = Transaction(
            date: .now, type: .creditCardPurchase, amountMinor: 320_000, currency: .COP,
            creditCard: card
        )
        let balance = BalanceService.currentCardBalance(for: card, transactions: [tx])
        #expect(balance.amountMinor == 320_000)
        #expect(balance.currency == .COP)
    }

    @Test func cardPaymentReducesCardDebt() {
        let card = CreditCard(name: "Lulo", bank: "Lulo", cutOffDay: 15, paymentDueDay: 5)
        let purchase = Transaction(
            date: .now, type: .creditCardPurchase, amountMinor: 500_000, currency: .COP,
            creditCard: card
        )
        let payment = Transaction(
            date: .now, type: .creditCardPayment, amountMinor: 200_000, currency: .COP,
            creditCard: card
        )
        let balance = BalanceService.currentCardBalance(for: card, transactions: [purchase, payment])
        #expect(balance.amountMinor == 300_000)
    }

    @Test func cardFeeIncreasesCardDebt() {
        let card = CreditCard(name: "Lulo", bank: "Lulo", cutOffDay: 15, paymentDueDay: 5)
        let fee = Transaction(
            date: .now, type: .feeOrInterest, amountMinor: 12_500, currency: .COP,
            creditCard: card
        )
        let balance = BalanceService.currentCardBalance(for: card, transactions: [fee])
        #expect(balance.amountMinor == 12_500)
    }

    @Test func bankFeeDoesNotAffectAnyCard() {
        let lulo = Account(name: "Lulo", type: .bank, initialBalanceMinor: 1_000_000)
        let card = CreditCard(name: "Lulo", bank: "Lulo", cutOffDay: 15, paymentDueDay: 5)
        let bankFee = Transaction(
            date: .now, type: .feeOrInterest, amountMinor: 15_000, currency: .COP,
            account: lulo
        )

        #expect(BalanceService.currentCardBalance(for: card, transactions: [bankFee]).amountMinor == 0)
        #expect(BalanceService.currentBalance(for: lulo, transactions: [bankFee]).amountMinor == 985_000)
    }

    @Test func unrelatedCardTransactionsAreIgnored() {
        let lulo = CreditCard(name: "Lulo", bank: "Lulo", cutOffDay: 15, paymentDueDay: 5)
        let nu = CreditCard(name: "Nu", bank: "Nu", cutOffDay: 20, paymentDueDay: 10)
        let purchaseOnNu = Transaction(
            date: .now, type: .creditCardPurchase, amountMinor: 100_000, currency: .COP,
            creditCard: nu
        )
        #expect(BalanceService.currentCardBalance(for: lulo, transactions: [purchaseOnNu]).amountMinor == 0)
        #expect(BalanceService.currentCardBalance(for: nu, transactions: [purchaseOnNu]).amountMinor == 100_000)
    }

    // MARK: - Credit card (account-side rules)

    @Test func creditCardPurchaseDoesNotMoveBankBalance() {
        let lulo = Account(name: "Lulo", type: .bank, initialBalanceMinor: 1_000_000)
        let tx = Transaction(
            date: .now, type: .creditCardPurchase, amountMinor: 320_000, currency: .COP,
            account: lulo
        )
        #expect(BalanceService.currentBalance(for: lulo, transactions: [tx]).amountMinor == 1_000_000)
    }

    @Test func creditCardPurchaseCountsAsSpending() {
        #expect(BalanceService.isSpending(type: .creditCardPurchase) == true)
    }

    @Test func creditCardPaymentReducesBankAccount() {
        let lulo = Account(name: "Lulo", type: .bank, initialBalanceMinor: 1_000_000)
        let tx = Transaction(
            date: .now, type: .creditCardPayment, amountMinor: 450_000, currency: .COP,
            account: lulo
        )
        #expect(BalanceService.currentBalance(for: lulo, transactions: [tx]).amountMinor == 550_000)
    }

    @Test func creditCardPaymentIsNotSpending() {
        #expect(BalanceService.isSpending(type: .creditCardPayment) == false)
    }

    // MARK: - Fee / interest / savings

    @Test func feeOrInterestCountsAsSpending() {
        #expect(BalanceService.isSpending(type: .feeOrInterest) == true)
    }

    @Test func savingsAllocationIsNotSpending() {
        #expect(BalanceService.isSpending(type: .savingsAllocation) == false)
    }

    @Test func savingsAllocationMovesBalanceWhenAccountsAreSet() {
        let lulo = Account(name: "Lulo", type: .bank, initialBalanceMinor: 1_000_000)
        let pocket = Account(name: "Lulo Pocket", type: .pocket, initialBalanceMinor: 0)
        let tx = Transaction(
            date: .now, type: .savingsAllocation, amountMinor: 300_000, currency: .COP,
            account: lulo, toAccount: pocket
        )

        #expect(BalanceService.currentBalance(for: lulo, transactions: [tx]).amountMinor == 700_000)
        #expect(BalanceService.currentBalance(for: pocket, transactions: [tx]).amountMinor == 300_000)
    }

    // MARK: - Aggregated totals

    @Test func totalBalanceSumsIncludeInTotalAccountsByCurrency() {
        let lulo = Account(name: "Lulo", type: .bank, initialBalanceMinor: 1_000_000)
        let nequi = Account(name: "Nequi", type: .wallet, initialBalanceMinor: 200_000)
        let global = Account(
            name: "Global66", type: .foreignWallet,
            currency: .USD, initialBalanceMinor: 50_000
        )
        let hidden = Account(
            name: "Oculta", type: .bank,
            initialBalanceMinor: 999_999, includeInTotal: false
        )

        let cop = BalanceService.totalBalance(
            currency: .COP,
            accounts: [lulo, nequi, global, hidden],
            transactions: []
        )
        let usd = BalanceService.totalBalance(
            currency: .USD,
            accounts: [lulo, nequi, global, hidden],
            transactions: []
        )

        #expect(cop.amountMinor == 1_200_000)
        #expect(usd.amountMinor == 50_000)
    }

    @Test func liquidBalanceExcludesPocketsAndForeignWallets() {
        let lulo = Account(name: "Lulo", type: .bank, initialBalanceMinor: 1_000_000)
        let pocket = Account(name: "Lulo Pocket", type: .pocket, initialBalanceMinor: 500_000)
        let cash = Account(name: "Efectivo", type: .cash, initialBalanceMinor: 100_000)
        let global = Account(
            name: "Global66", type: .foreignWallet,
            currency: .USD, initialBalanceMinor: 50_000
        )

        let liquid = BalanceService.liquidBalance(
            currency: .COP,
            accounts: [lulo, pocket, cash, global],
            transactions: []
        )
        #expect(liquid.amountMinor == 1_100_000)
    }

    @Test func transactionsOutsideDateRangeAreExcluded() {
        let nequi = Account(name: "Nequi", type: .wallet, initialBalanceMinor: 0)
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let inside = Transaction(date: now, type: .expense, amountMinor: 10_000, currency: .COP, account: nequi)
        let outside = Transaction(
            date: cal.date(byAdding: .day, value: -10, to: now)!,
            type: .expense, amountMinor: 999_000, currency: .COP, account: nequi
        )
        let from = cal.date(byAdding: .day, value: -1, to: now)!
        let to = cal.date(byAdding: .day, value: 1, to: now)!

        let spending = BalanceService.totalSpending(in: [inside, outside], from: from, to: to, currency: .COP)
        #expect(spending.amountMinor == 10_000)
    }

    // MARK: - Helpers

    /// Returns a [date - 1 day, date + 1 day] window — large enough to cover any
    /// `.now`-tagged transaction created during a single test.
    private func dayWindow(around date: Date) -> (Date, Date) {
        let cal = Calendar(identifier: .gregorian)
        return (
            cal.date(byAdding: .day, value: -1, to: date)!,
            cal.date(byAdding: .day, value: 1, to: date)!
        )
    }
}
