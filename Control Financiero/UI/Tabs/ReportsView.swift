import SwiftUI
import SwiftData
import Charts

/// Reportes — visual summary of spending over the last 30 days, a category breakdown,
/// and the list of upcoming payments. All numbers come from pure services so this view
/// is just presentation.
struct ReportsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var bills: [RecurringBill]
    @Query private var debts: [Debt]
    @Query private var cards: [CreditCard]

    @State private var rangeDays: Int = 30

    var body: some View {
        NavigationStack {
            List {
                rangePicker
                chartSection
                categorySection
                upcomingSection
            }
            .navigationTitle("Reportes")
        }
    }

    // MARK: - Sections

    private var rangePicker: some View {
        Section {
            Picker("Rango", selection: $rangeDays) {
                Text("7 días").tag(7)
                Text("30 días").tag(30)
                Text("90 días").tag(90)
            }
            .pickerStyle(.segmented)
        }
    }

    private var chartSection: some View {
        Section("Gasto diario") {
            if daily.isEmpty {
                ContentUnavailableView(
                    "Sin gastos en este rango",
                    systemImage: "chart.bar",
                    description: Text("Registra movimientos para ver el gráfico.")
                )
            } else {
                Chart(daily) { item in
                    BarMark(
                        x: .value("Día", item.date, unit: .day),
                        y: .value("Monto", Double(item.amount.amountMinor))
                    )
                    .foregroundStyle(.orange)
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(MoneyFormatter.format(Money(amountMinor: Int64(v), currency: .COP)))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                HStack {
                    Text("Total")
                        .font(.subheadline)
                    Spacer()
                    Text(MoneyFormatter.format(totalSpending))
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private var categorySection: some View {
        Section("Por categoría") {
            if byCategory.isEmpty {
                Text("Sin movimientos")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(byCategory) { row in
                    CategorySpendingRow(row: row, max: byCategory.first?.amount.amountMinor ?? 1)
                }
            }
        }
    }

    private var upcomingSection: some View {
        Section("Próximos pagos") {
            if upcoming.isEmpty {
                Text("Sin pagos próximos")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(upcoming) { payment in
                    UpcomingPaymentRow(payment: payment)
                }
            }
        }
    }

    // MARK: - Derived

    private var window: (start: Date, end: Date) {
        let cal = Calendar(identifier: .gregorian)
        let end = cal.startOfDay(for: .now).addingTimeInterval(60*60*24 - 1)
        let start = cal.date(byAdding: .day, value: -(rangeDays - 1), to: cal.startOfDay(for: .now)) ?? .now
        return (start, end)
    }

    private var daily: [ReportService.DailySpending] {
        ReportService.spendingByDay(
            in: transactions, from: window.start, to: window.end, currency: .COP
        )
    }

    private var byCategory: [ReportService.CategorySpending] {
        ReportService.spendingByCategory(
            in: transactions, from: window.start, to: window.end, currency: .COP
        )
    }

    private var totalSpending: Money {
        BalanceService.totalSpending(in: transactions, from: window.start, to: window.end, currency: .COP)
    }

    private var upcoming: [UpcomingPayment] {
        UpcomingPaymentService.upcomingPayments(
            bills: bills, debts: debts, cards: cards, transactions: transactions
        )
    }
}

// MARK: - Rows

private struct CategorySpendingRow: View {
    let row: ReportService.CategorySpending
    let max: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(color(for: row.group))
                    .frame(width: 8, height: 8)
                Text(row.categoryName)
                    .font(.subheadline)
                Spacer()
                Text(MoneyFormatter.format(row.amount))
                    .font(.subheadline.weight(.semibold))
            }
            ProgressView(value: Double(row.amount.amountMinor) / Double(Swift.max(max, 1)))
                .tint(color(for: row.group))
        }
        .padding(.vertical, 2)
    }

    private func color(for group: BudgetGroup) -> Color {
        switch group {
        case .needs: .blue
        case .wants: .orange
        case .savingsDebt: .purple
        case .excluded: .gray
        }
    }
}

private struct UpcomingPaymentRow: View {
    let payment: UpcomingPayment

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.name)
                    .font(.subheadline)
                Text(dateLabel)
                    .font(.caption)
                    .foregroundStyle(isOverdue ? .red : .secondary)
            }
            Spacer()
            Text(MoneyFormatter.format(payment.amount))
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 2)
    }

    private var icon: String {
        switch payment.kind {
        case .bill: "doc.text"
        case .debt: "creditcard.trianglebadge.exclamationmark"
        case .card: "creditcard"
        }
    }

    private var tint: Color {
        switch payment.kind {
        case .bill: .blue
        case .debt: .red
        case .card: .orange
        }
    }

    private var isOverdue: Bool {
        payment.isOverdue(asOf: .now)
    }

    private var dateLabel: String {
        let formatted = payment.dueDate.formatted(date: .abbreviated, time: .omitted)
        return isOverdue ? String(localized: "Vencido") + " · " + formatted : formatted
    }
}
