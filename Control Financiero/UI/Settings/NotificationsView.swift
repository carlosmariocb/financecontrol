import SwiftUI
import SwiftData
import UserNotifications

/// Permission state + a "Reschedule now" action that re-syncs reminders with the
/// current set of bills, debts, and card statements. The user toggles reminders
/// on/off; we request system permission lazily on the first enable.
struct NotificationsView: View {
    @Query private var bills: [RecurringBill]
    @Query private var debts: [Debt]
    @Query private var cards: [CreditCard]
    @Query private var transactions: [Transaction]

    @AppStorage("notifications.enabled") private var enabled: Bool = false

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var lastRescheduledAt: Date?
    @State private var working: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("Activar recordatorios", isOn: Binding(
                    get: { enabled },
                    set: { newValue in
                        enabled = newValue
                        Task { await handleToggle(newValue) }
                    }
                ))
            } header: {
                Text("Recordatorios")
            } footer: {
                Text("Te avisamos de facturas, deudas y pagos de tarjeta antes de la fecha límite. Todo es local — no salimos a la red.")
            }

            Section("Estado del sistema") {
                LabeledContent("Permiso") { Text(authLabel).foregroundStyle(.secondary) }
                if let lastRescheduledAt {
                    LabeledContent("Programados") {
                        Text(lastRescheduledAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if enabled {
                Section {
                    Button {
                        Task { await rescheduleNow() }
                    } label: {
                        Label("Recalcular ahora", systemImage: "arrow.clockwise")
                    }
                    .disabled(working)
                }
            }
        }
        .navigationTitle("Notificaciones")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            authStatus = await ReminderService.currentStatus()
        }
    }

    private var authLabel: String {
        switch authStatus {
        case .authorized: String(localized: "Autorizado")
        case .denied: String(localized: "Denegado")
        case .notDetermined: String(localized: "Pendiente")
        case .provisional: String(localized: "Provisional")
        case .ephemeral: String(localized: "Temporal")
        @unknown default: ""
        }
    }

    private func handleToggle(_ newValue: Bool) async {
        if newValue {
            let granted = await ReminderService.requestAuthorization()
            authStatus = await ReminderService.currentStatus()
            if granted {
                await rescheduleNow()
            } else {
                enabled = false
            }
        } else {
            await ReminderService.cancelAll()
            lastRescheduledAt = nil
        }
    }

    private func rescheduleNow() async {
        working = true
        defer { working = false }
        let payments = UpcomingPaymentService.upcomingPayments(
            bills: bills, debts: debts, cards: cards, transactions: transactions
        )
        await ReminderService.reschedule(payments)
        lastRescheduledAt = .now
    }
}
