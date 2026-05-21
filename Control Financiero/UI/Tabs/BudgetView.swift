import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetPeriod.startDate, order: .reverse) private var periods: [BudgetPeriod]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var resolvedPeriod: BudgetPeriod?

    var body: some View {
        NavigationStack {
            Group {
                if let period = resolvedPeriod {
                    periodBody(period)
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .navigationTitle("Presupuesto")
            .toolbar {
                if let period = resolvedPeriod {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            BudgetPeriodEditView(period: period)
                        } label: {
                            Label("Editar", systemImage: "slider.horizontal.3")
                        }
                    }
                }
            }
        }
        .onAppear(perform: ensureCurrentPeriod)
    }

    // MARK: - Body for resolved period

    @ViewBuilder
    private func periodBody(_ period: BudgetPeriod) -> some View {
        let spending = BudgetPeriodService.spendingByGroup(in: period, transactions: transactions)
        let safe = BudgetPeriodService.safeToSpend(period: period, transactions: transactions)

        List {
            headerSection(period: period)
            safeToSpendSection(period: period, safe: safe)
            groupSection(
                title: "Necesidades",
                spent: spending.needs,
                limit: period.needsLimitMinor,
                currency: period.currency,
                tint: .blue
            )
            groupSection(
                title: "Gustos",
                spent: spending.wants,
                limit: period.wantsLimitMinor,
                currency: period.currency,
                tint: .orange
            )
            groupSection(
                title: "Ahorro / Deuda",
                spent: spending.savingsDebt,
                limit: period.savingsDebtLimitMinor,
                currency: period.currency,
                tint: .purple
            )
            if spending.excluded.amountMinor > 0 {
                Section {
                    HStack {
                        Text("Excluido del presupuesto")
                        Spacer()
                        Text(MoneyFormatter.format(spending.excluded))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Sections

    private func headerSection(period: BudgetPeriod) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(periodLabel(period))
                    .font(.headline)
                HStack {
                    Text("Ingreso planeado")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(MoneyFormatter.format(Money(amountMinor: period.incomePlannedMinor, currency: period.currency)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func safeToSpendSection(period: BudgetPeriod, safe: Money) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Disponible para gastar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(MoneyFormatter.format(safe))
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                Text("Necesidades + Gustos restantes en esta quincena")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func groupSection(
        title: LocalizedStringKey,
        spent: Money,
        limit: Int64,
        currency: Currency,
        tint: Color
    ) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(MoneyFormatter.format(spent) + " / " + MoneyFormatter.format(Money(amountMinor: limit, currency: currency)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progressFraction(spent: spent.amountMinor, limit: limit))
                    .tint(progressFraction(spent: spent.amountMinor, limit: limit) > 1.0 ? .red : tint)
                if limit > 0 {
                    let remaining = max(0, limit - spent.amountMinor)
                    Text("Restante: " + MoneyFormatter.format(Money(amountMinor: remaining, currency: currency)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Helpers

    private func progressFraction(spent: Int64, limit: Int64) -> Double {
        guard limit > 0 else { return 0 }
        return min(max(Double(spent) / Double(limit), 0), 1.5)
    }

    private func periodLabel(_ period: BudgetPeriod) -> String {
        let start = period.startDate.formatted(.dateTime.day().month(.abbreviated))
        let end = period.endDate.formatted(.dateTime.day().month(.abbreviated))
        return "\(start) – \(end)"
    }

    // MARK: - Period resolution

    /// Find the BudgetPeriod whose [start,end] contains today. If none exists,
    /// create one anchored to today's quincena with default (zero) limits — the user
    /// will fill it in via the editor.
    private func ensureCurrentPeriod() {
        let today = Date()
        if let existing = periods.first(where: { period in
            today >= period.startDate && today <= period.endDate && period.currency == .COP
        }) {
            resolvedPeriod = existing
            return
        }

        let window = BudgetPeriodService.quincenalWindow(containing: today)
        let new = BudgetPeriod(
            startDate: window.start,
            endDate: window.end,
            currency: .COP
        )
        modelContext.insert(new)
        resolvedPeriod = new
    }
}
