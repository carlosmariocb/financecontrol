import SwiftUI

/// "Configuración" hub — links into management screens for every user-curatable
/// entity, plus backup and notification settings. Pushed onto Home's NavigationStack
/// from the gear toolbar button.
struct SettingsView: View {
    var body: some View {
        List {
            Section("Datos") {
                NavigationLink {
                    AccountsListView()
                } label: {
                    Label("Cuentas", systemImage: "wallet.pass")
                }
                NavigationLink {
                    CardsListView()
                } label: {
                    Label("Tarjetas", systemImage: "creditcard")
                }
                NavigationLink {
                    CategoriesListView()
                } label: {
                    Label("Categorías", systemImage: "folder")
                }
                NavigationLink {
                    GoalsListView()
                } label: {
                    Label("Metas", systemImage: "target")
                }
                NavigationLink {
                    RecurringBillsListView()
                } label: {
                    Label("Facturas", systemImage: "doc.text")
                }
                NavigationLink {
                    DebtsListView()
                } label: {
                    Label("Deudas", systemImage: "creditcard.trianglebadge.exclamationmark")
                }
            }

            Section("Sistema") {
                NavigationLink {
                    NotificationsView()
                } label: {
                    Label("Notificaciones", systemImage: "bell")
                }
                NavigationLink {
                    BackupView()
                } label: {
                    Label("Respaldo", systemImage: "externaldrive")
                }
            }
        }
        .navigationTitle("Configuración")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
