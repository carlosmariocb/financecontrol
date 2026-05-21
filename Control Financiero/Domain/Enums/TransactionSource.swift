import Foundation

nonisolated enum TransactionSource: String, Codable, CaseIterable, Sendable {
    case manual
    case text
    case voice
    case ai
    case importedBackup = "imported_backup"
}
