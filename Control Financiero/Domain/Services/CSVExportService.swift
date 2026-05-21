import Foundation

/// Exports `Transaction`s to RFC 4180 CSV. The output is intentionally human-readable:
/// amounts are written in major units with the period as decimal separator (matching
/// what spreadsheet apps expect), and the currency goes in its own column.
nonisolated enum CSVExportService {

    private static let header = [
        "date",
        "type",
        "amount",
        "currency",
        "account",
        "to_account",
        "card",
        "category",
        "subcategory",
        "merchant",
        "details",
        "source"
    ]

    static func csv(for transactions: [Transaction]) -> String {
        var lines: [String] = [header.joined(separator: ",")]
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let sorted = transactions.sorted { $0.date < $1.date }
        for tx in sorted {
            let row = [
                isoFormatter.string(from: tx.date),
                tx.type.rawValue,
                formatAmount(tx.amountMinor, currency: tx.currency),
                tx.currency.rawValue,
                tx.account?.name ?? "",
                tx.toAccount?.name ?? "",
                tx.creditCard?.name ?? "",
                tx.category?.name ?? "",
                tx.subcategory?.name ?? "",
                tx.merchant ?? "",
                tx.details ?? "",
                tx.source.rawValue
            ]
            lines.append(row.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Format an integer minor-unit amount as a decimal string in the unit the
    /// currency conventionally uses. COP has no fractions; USD uses two decimals.
    private static func formatAmount(_ minor: Int64, currency: Currency) -> String {
        switch currency {
        case .COP:
            return String(minor)
        case .USD:
            let dollars = minor / 100
            let remainder = abs(minor % 100)
            return String(format: "%lld.%02lld", dollars, remainder)
        }
    }

    /// RFC 4180 escaping: if the field contains a comma, quote, or newline, wrap it
    /// in quotes and double any embedded quotes.
    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}
