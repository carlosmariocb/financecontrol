import Foundation
import Testing
@testable import Control_Financiero

struct ReportServiceTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Bogota") ?? .current
        return cal
    }()

    // MARK: - spendingByDay

    @Test func dailyBucketsAreCollapsedByCalendarDay() {
        let cat = TransactionCategory(name: "Mercado", budgetGroup: .needs)
        let txs = [
            Transaction(date: dt(2026, 5, 3, 9, 0), type: .expense, amountMinor: 10_000, currency: .COP, category: cat),
            Transaction(date: dt(2026, 5, 3, 20, 0), type: .expense, amountMinor: 5_000, currency: .COP, category: cat),
            Transaction(date: dt(2026, 5, 5, 12, 0), type: .expense, amountMinor: 20_000, currency: .COP, category: cat),
        ]
        let result = ReportService.spendingByDay(
            in: txs, from: dt(2026, 5, 1, 0, 0), to: dt(2026, 5, 31, 23, 59),
            currency: .COP, calendar: calendar
        )

        #expect(result.count == 2)
        #expect(result[0].amount.amountMinor == 15_000) // May 3
        #expect(result[1].amount.amountMinor == 20_000) // May 5
    }

    @Test func dailyExcludesTransfersAndPayments() {
        let cat = TransactionCategory(name: "Mercado", budgetGroup: .needs)
        let txs = [
            Transaction(date: dt(2026, 5, 3, 9, 0), type: .expense, amountMinor: 10_000, currency: .COP, category: cat),
            Transaction(date: dt(2026, 5, 3, 10, 0), type: .transfer, amountMinor: 500_000, currency: .COP),
            Transaction(date: dt(2026, 5, 3, 11, 0), type: .creditCardPayment, amountMinor: 200_000, currency: .COP),
            Transaction(date: dt(2026, 5, 3, 12, 0), type: .income, amountMinor: 1_000_000, currency: .COP),
        ]
        let result = ReportService.spendingByDay(
            in: txs, from: dt(2026, 5, 1, 0, 0), to: dt(2026, 5, 31, 23, 59),
            currency: .COP, calendar: calendar
        )
        #expect(result.count == 1)
        #expect(result.first?.amount.amountMinor == 10_000)
    }

    // MARK: - spendingByCategory

    @Test func categoryAggregatesRollUpSubcategoriesToParent() {
        let parent = TransactionCategory(name: "Comida", budgetGroup: .needs)
        let sub = TransactionCategory(name: "Restaurantes", budgetGroup: .wants, parent: parent)
        let other = TransactionCategory(name: "Transporte", budgetGroup: .needs)

        let txs = [
            Transaction(date: dt(2026, 5, 1, 12, 0), type: .expense, amountMinor: 30_000, currency: .COP, category: parent),
            Transaction(date: dt(2026, 5, 2, 12, 0), type: .expense, amountMinor: 50_000, currency: .COP, category: sub, subcategory: sub),
            Transaction(date: dt(2026, 5, 3, 12, 0), type: .expense, amountMinor: 20_000, currency: .COP, category: other),
        ]
        let result = ReportService.spendingByCategory(
            in: txs, from: dt(2026, 5, 1, 0, 0), to: dt(2026, 5, 31, 23, 59), currency: .COP
        )

        // Restaurantes (sub of Comida) should fold into Comida; total = 80_000
        let comida = result.first { $0.categoryName == "Comida" }
        #expect(comida?.amount.amountMinor == 80_000)
        let trans = result.first { $0.categoryName == "Transporte" }
        #expect(trans?.amount.amountMinor == 20_000)
        // Sorted descending: Comida before Transporte
        #expect(result.first?.categoryName == "Comida")
    }

    @Test func uncategorizedSpendingShowsUpAsSinCategoria() {
        let txs = [
            Transaction(date: dt(2026, 5, 1, 12, 0), type: .expense, amountMinor: 12_345, currency: .COP),
        ]
        let result = ReportService.spendingByCategory(
            in: txs, from: dt(2026, 5, 1, 0, 0), to: dt(2026, 5, 31, 23, 59), currency: .COP
        )
        #expect(result.count == 1)
        #expect(result.first?.categoryName == "Sin categoría")
        #expect(result.first?.group == .excluded)
    }

    private func dt(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
        return calendar.date(from: c)!
    }
}
