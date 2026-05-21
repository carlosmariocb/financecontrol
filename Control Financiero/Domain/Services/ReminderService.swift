import Foundation
import UserNotifications

/// Local-notification scheduler for upcoming bills, debts, and card statements.
///
/// All notifications are scheduled relative to an `UpcomingPayment.dueDate` minus the
/// item's `reminderDaysBefore`. Reminders fire at 9:00 AM local time on the chosen day.
///
/// The "Local-first" constraint applies: no network calls, no external services.
@MainActor
enum ReminderService {

    /// Identifier prefix so we can wipe all of *our* notifications without touching
    /// anything else the app might schedule in the future.
    private static let idPrefix = "cf.reminder."

    // MARK: - Authorization

    /// Asks for permission if not yet granted. Idempotent; safe to call repeatedly.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    static func currentStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    /// Replaces all currently-scheduled reminders with one per upcoming payment.
    /// Uses a deterministic id per item so reschedules don't pile up duplicates.
    static func reschedule(_ payments: [UpcomingPayment], calendar: Calendar = Calendar(identifier: .gregorian)) async {
        let center = UNUserNotificationCenter.current()
        await cancelAll()

        for payment in payments {
            guard let triggerDate = reminderDate(for: payment, calendar: calendar) else { continue }
            // Skip items where the reminder day is already in the past.
            guard triggerDate > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = title(for: payment.kind)
            content.body = body(for: payment)
            content.sound = .default

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let id = idPrefix + payment.kind.rawValue + "." + payment.id.uuidString
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                // A single failing request shouldn't stop the rest; just continue.
                continue
            }
        }
    }

    /// Cancels every reminder this app scheduled (identified by `idPrefix`).
    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }

    // MARK: - Content

    private static func reminderDate(for payment: UpcomingPayment, calendar: Calendar) -> Date? {
        let day = calendar.date(byAdding: .day, value: -payment.reminderDaysBefore, to: payment.dueDate) ?? payment.dueDate
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = 9
        comps.minute = 0
        return calendar.date(from: comps)
    }

    private static func title(for kind: UpcomingPayment.Kind) -> String {
        switch kind {
        case .bill: String(localized: "Factura por pagar")
        case .debt: String(localized: "Pago de deuda")
        case .card: String(localized: "Pago de tarjeta")
        }
    }

    private static func body(for payment: UpcomingPayment) -> String {
        let amount = MoneyFormatter.format(payment.amount)
        let date = payment.dueDate.formatted(date: .abbreviated, time: .omitted)
        return "\(payment.name) — \(amount) · vence \(date)"
    }
}
