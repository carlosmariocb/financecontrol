import SwiftUI
import SwiftData

struct DebtsListView: View {
    @Query(sort: \Debt.name) private var debts: [Debt]

    var body: some View {
        List {
            if debts.isEmpty {
                ContentUnavailableView(
                    "Sin deudas",
                    systemImage: "creditcard.trianglebadge.exclamationmark",
                    description: Text("Toca + para registrar una deuda.")
                )
            } else {
                ForEach(debts) { debt in
                    NavigationLink {
                        DebtEditView(editing: debt)
                    } label: {
                        DebtRow(debt: debt)
                    }
                }
            }
        }
        .navigationTitle("Deudas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    DebtEditView(editing: nil)
                } label: {
                    Label("Nueva deuda", systemImage: "plus")
                }
            }
        }
    }
}

private struct DebtRow: View {
    let debt: Debt

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(debt.name).font(.body)
                Spacer()
                Text(MoneyFormatter.format(Money(amountMinor: debt.currentBalanceMinor, currency: debt.currency)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            if debt.paymentAmountMinor > 0 {
                HStack {
                    Text("Cuota mensual")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(MoneyFormatter.format(Money(amountMinor: debt.paymentAmountMinor, currency: debt.currency)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if debt.originalAmountMinor > 0 {
                let fraction = max(0, min(1, 1 - Double(debt.currentBalanceMinor) / Double(debt.originalAmountMinor)))
                ProgressView(value: fraction)
                    .tint(.green)
            }
        }
        .padding(.vertical, 2)
    }
}
