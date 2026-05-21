import SwiftUI
import SwiftData

struct CardsDebtsView: View {
    @Query(sort: \CreditCard.name) private var cards: [CreditCard]
    @Query private var transactions: [Transaction]
    @Query(sort: \InstallmentPlan.startDate, order: .reverse) private var plans: [InstallmentPlan]

    var body: some View {
        NavigationStack {
            List {
                if cards.isEmpty {
                    ContentUnavailableView(
                        "Sin tarjetas",
                        systemImage: "creditcard",
                        description: Text("Aún no hay tarjetas registradas.")
                    )
                } else {
                    cardsSection
                    if !activePlans.isEmpty {
                        plansSection
                    }
                }
            }
            .navigationTitle("Tarjetas")
        }
    }

    // MARK: - Sections

    private var cardsSection: some View {
        Section("Tarjetas") {
            ForEach(cards) { card in
                NavigationLink {
                    CreditCardEditView(editing: card)
                } label: {
                    CardRow(card: card, transactions: transactions)
                }
            }
        }
    }

    private var plansSection: some View {
        Section("Cuotas activas") {
            ForEach(activePlans) { plan in
                InstallmentRow(plan: plan)
            }
        }
    }

    // MARK: - Derived

    private var activePlans: [InstallmentPlan] {
        plans.filter { $0.remainingInstallments > 0 }
    }
}

// MARK: - Card row

private struct CardRow: View {
    let card: CreditCard
    let transactions: [Transaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.name)
                    .font(.headline)
                Spacer()
                Text(MoneyFormatter.format(currentBalance))
                    .font(.headline)
                    .foregroundStyle(currentBalance.amountMinor > 0 ? .orange : .secondary)
            }
            Text(card.bank)
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
                .padding(.vertical, 2)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Próximo pago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(MoneyFormatter.format(currentCycle))
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Fecha límite")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(nextDue.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                }
            }
            if let limit = card.limitMinor, limit > 0 {
                ProgressView(value: progressFraction)
                    .tint(progressFraction > 0.9 ? .red : .accentColor)
                HStack {
                    Text("Cupo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(MoneyFormatter.format(Money(amountMinor: limit, currency: card.currency)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Derived

    private var currentBalance: Money {
        BalanceService.currentCardBalance(for: card, transactions: transactions)
    }

    private var currentCycle: Money {
        CardCycleService.currentCycleSpending(for: card, transactions: transactions, asOf: .now)
    }

    private var nextDue: Date {
        CardCycleService.nextPaymentDueDate(for: card, asOf: .now)
    }

    private var progressFraction: Double {
        guard let limit = card.limitMinor, limit > 0 else { return 0 }
        return min(max(Double(currentBalance.amountMinor) / Double(limit), 0), 1)
    }
}

// MARK: - Installment row

private struct InstallmentRow: View {
    let plan: InstallmentPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(plan.creditCard?.name ?? "")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(plan.remainingInstallments)/\(plan.numberOfInstallments)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(MoneyFormatter.format(monthly))
                    .font(.body)
                Spacer()
                Text(MoneyFormatter.format(total))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var monthly: Money {
        Money(amountMinor: plan.monthlyAmountMinor, currency: plan.currency)
    }

    private var total: Money {
        Money(amountMinor: plan.totalAmountMinor, currency: plan.currency)
    }
}
