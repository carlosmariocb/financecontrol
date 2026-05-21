import Foundation
import Testing
@testable import Control_Financiero

struct CSVExportServiceTests {

    @Test func csvIncludesHeaderAndOneRowPerTransaction() {
        let acc = Account(name: "Lulo", type: .bank, initialBalanceMinor: 0)
        let txs = [
            Transaction(date: Date(timeIntervalSince1970: 1_700_000_000),
                        type: .expense, amountMinor: 30_000, currency: .COP, account: acc),
            Transaction(date: Date(timeIntervalSince1970: 1_700_100_000),
                        type: .income, amountMinor: 1_000_000, currency: .COP, account: acc),
        ]
        let csv = CSVExportService.csv(for: txs)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)

        #expect(lines.count == 3)
        #expect(lines[0].contains("date,type,amount,currency"))
    }

    @Test func fieldsWithCommasAreQuoted() {
        let acc = Account(name: "Lulo", type: .bank, initialBalanceMinor: 0)
        let tx = Transaction(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            type: .expense, amountMinor: 30_000, currency: .COP,
            account: acc, merchant: "Café, té y más"
        )
        let csv = CSVExportService.csv(for: [tx])
        #expect(csv.contains("\"Café, té y más\""))
    }

    @Test func usdAmountsAreWrittenAsDecimals() {
        let acc = Account(name: "Global66", type: .foreignWallet, currency: .USD, initialBalanceMinor: 0)
        let tx = Transaction(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            type: .expense, amountMinor: 12_345, currency: .USD, account: acc
        )
        let csv = CSVExportService.csv(for: [tx])
        #expect(csv.contains(",123.45,USD,"))
    }

    @Test func copAmountsAreWrittenAsIntegers() {
        let acc = Account(name: "Lulo", type: .bank, initialBalanceMinor: 0)
        let tx = Transaction(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            type: .expense, amountMinor: 30_000, currency: .COP, account: acc
        )
        let csv = CSVExportService.csv(for: [tx])
        #expect(csv.contains(",30000,COP,"))
    }
}
