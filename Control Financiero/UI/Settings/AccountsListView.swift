import SwiftUI
import SwiftData

struct AccountsListView: View {
    @Query(sort: \Account.name) private var accounts: [Account]

    var body: some View {
        List {
            if accounts.isEmpty {
                ContentUnavailableView(
                    "Sin cuentas",
                    systemImage: "wallet.pass",
                    description: Text("Toca + para crear tu primera cuenta.")
                )
            } else {
                ForEach(accounts) { account in
                    NavigationLink {
                        AccountEditView(editing: account)
                    } label: {
                        AccountListRow(account: account)
                    }
                }
            }
        }
        .navigationTitle("Cuentas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    AccountEditView(editing: nil)
                } label: {
                    Label("Nueva cuenta", systemImage: "plus")
                }
            }
        }
    }
}

private struct AccountListRow: View {
    let account: Account

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.body)
                Text(typeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(account.currency.rawValue)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.tertiary, in: .capsule)
        }
    }

    private var typeLabel: String {
        switch account.type {
        case .bank: "Banco"
        case .wallet: "Billetera"
        case .cash: "Efectivo"
        case .pocket: "Bolsillo"
        case .foreignWallet: "Billetera extranjera"
        }
    }
}
