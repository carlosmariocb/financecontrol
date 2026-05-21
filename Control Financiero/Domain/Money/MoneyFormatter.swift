import Foundation

nonisolated enum MoneyFormatter {
    static func format(_ money: Money) -> String {
        switch money.currency {
        case .COP: formatCOP(money.amountMinor)
        case .USD: formatUSD(cents: money.amountMinor)
        }
    }

    private static func formatCOP(_ pesos: Int64) -> String {
        let isNegative = pesos < 0
        let magnitude = isNegative ? -pesos : pesos
        let body = grouped(String(magnitude), separator: ".")
        return (isNegative ? "-$" : "$") + body
    }

    private static func formatUSD(cents: Int64) -> String {
        let isNegative = cents < 0
        let magnitude = isNegative ? -cents : cents
        let dollars = magnitude / 100
        let fractional = magnitude % 100
        let dollarBody = grouped(String(dollars), separator: ",")
        let fractionalBody = String(format: "%02d", fractional)
        return (isNegative ? "-$" : "$") + "\(dollarBody).\(fractionalBody)"
    }

    private static func grouped(_ digits: String, separator: String) -> String {
        var result = ""
        for (index, character) in digits.reversed().enumerated() {
            if index > 0, index % 3 == 0 { result.append(separator) }
            result.append(character)
        }
        return String(result.reversed())
    }
}
