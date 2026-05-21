import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    var body: some View {
        NavigationStack {
            List {
                balanceSection
                transactionsSection
            }
            .navigationTitle("Inicio")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Configuración", systemImage: "gearshape")
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var balanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Saldo total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(MoneyFormatter.format(copTotal))
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                if usdTotal.amountMinor != 0 {
                    Text(MoneyFormatter.format(usdTotal))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Divider()
                    .padding(.vertical, 2)
                HStack {
                    Text("Disponible")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(MoneyFormatter.format(copLiquid))
                        .font(.headline)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var transactionsSection: some View {
        Section("Movimientos recientes") {
            if transactions.isEmpty {
                ContentUnavailableView(
                    "Sin movimientos todavía",
                    systemImage: "tray",
                    description: Text("Aún no has registrado movimientos. Toca Agregar para empezar.")
                )
            } else {
                ForEach(recentTransactions) { tx in
                    NavigationLink {
                        TransactionFormView(editing: tx)
                    } label: {
                        TransactionRow(transaction: tx)
                    }
                }
                .onDelete(perform: deleteRecent)
            }
        }
    }

    // MARK: - Mutation

    private var recentTransactions: [Transaction] {
        Array(transactions.prefix(10))
    }

    /// Indices come from the rendered `recentTransactions` array, which is the head
    /// of `transactions`, so they map 1:1.
    private func deleteRecent(at offsets: IndexSet) {
        for offset in offsets {
            let tx = recentTransactions[offset]
            if let plan = tx.installmentPlan {
                modelContext.delete(plan)
            }
            modelContext.delete(tx)
        }
    }

    // MARK: - Derived

    private var copTotal: Money {
        BalanceService.totalBalance(currency: .COP, accounts: accounts, transactions: transactions)
    }

    private var copLiquid: Money {
        BalanceService.liquidBalance(currency: .COP, accounts: accounts, transactions: transactions)
    }

    private var usdTotal: Money {
        BalanceService.totalBalance(currency: .USD, accounts: accounts, transactions: transactions)
    }
}

private struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryLabel)
                    .font(.body)
                    .lineLimit(1)
                if let secondary = secondaryLabel {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(signedAmount)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Visuals

    private var amountMoney: Money {
        Money(amountMinor: transaction.amountMinor, currency: transaction.currency)
    }

    private var signedAmount: String {
        let formatted = MoneyFormatter.format(amountMoney)
        switch transaction.type {
        case .income:
            return "+\(formatted)"
        case .expense, .creditCardPurchase, .feeOrInterest, .debtPayment, .creditCardPayment:
            return "-\(formatted)"
        case .transfer, .savingsAllocation:
            return formatted
        }
    }

    private var icon: String {
        switch transaction.type {
        case .income: "arrow.down.circle.fill"
        case .expense, .creditCardPurchase, .feeOrInterest, .debtPayment, .creditCardPayment: "arrow.up.circle.fill"
        case .transfer: "arrow.left.arrow.right.circle.fill"
        case .savingsAllocation: "banknote.fill"
        }
    }

    private var tint: Color {
        switch transaction.type {
        case .income: .green
        case .expense, .creditCardPurchase, .feeOrInterest, .debtPayment, .creditCardPayment: .orange
        case .transfer: .blue
        case .savingsAllocation: .purple
        }
    }

    private var primaryLabel: String {
        if let category = transaction.category {
            if let parent = category.parent {
                return "\(parent.name) › \(category.name)"
            }
            return category.name
        }
        switch transaction.type {
        case .income: return String(localized: "Ingreso")
        case .expense: return String(localized: "Gasto")
        case .transfer:
            if let toName = transaction.toAccount?.name {
                return String(localized: "Transferencia") + " → \(toName)"
            }
            return String(localized: "Transferencia")
        case .creditCardPurchase: return "Compra con tarjeta"
        case .creditCardPayment: return "Pago de tarjeta"
        case .feeOrInterest: return "Cargo / Interés"
        case .savingsAllocation: return "Ahorro"
        case .debtPayment: return "Pago de deuda"
        }
    }

    private var secondaryLabel: String? {
        let accountName = transaction.account?.name ?? ""
        let dateStr = transaction.date.formatted(date: .abbreviated, time: .omitted)
        if let merchant = transaction.merchant, !merchant.isEmpty {
            return "\(merchant) • \(accountName) • \(dateStr)"
        }
        if accountName.isEmpty {
            return dateStr
        }
        return "\(accountName) • \(dateStr)"
    }
}
