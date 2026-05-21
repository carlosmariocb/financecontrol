import Foundation

nonisolated enum Currency: String, Codable, CaseIterable, Sendable {
    case COP
    case USD

    var minorUnitsPerMajor: Int {
        switch self {
        case .COP: 1
        case .USD: 100
        }
    }

    var displayLocale: Locale {
        switch self {
        case .COP: Locale(identifier: "es_CO")
        case .USD: Locale(identifier: "en_US")
        }
    }
}
