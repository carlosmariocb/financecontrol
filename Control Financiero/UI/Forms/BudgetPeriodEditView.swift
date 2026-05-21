import SwiftUI
import SwiftData

/// Edits a single `BudgetPeriod` — income, three limits, and rollover. Includes a
/// one-tap "Aplicar 50/30/20" action that backfills the limits from the income.
/// Uses staged `@State` so back-swiping without "Guardar" leaves the period untouched.
struct BudgetPeriodEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let period: BudgetPeriod

    @State private var incomeText: String
    @State private var needsText: String
    @State private var wantsText: String
    @State private var savingsText: String
    @State private var rolloverText: String

    init(period: BudgetPeriod) {
        self.period = period
        _incomeText = State(initialValue: Self.format(amountMinor: period.incomePlannedMinor, currency: period.currency))
        _needsText = State(initialValue: Self.format(amountMinor: period.needsLimitMinor, currency: period.currency))
        _wantsText = State(initialValue: Self.format(amountMinor: period.wantsLimitMinor, currency: period.currency))
        _savingsText = State(initialValue: Self.format(amountMinor: period.savingsDebtLimitMinor, currency: period.currency))
        _rolloverText = State(initialValue: Self.format(amountMinor: period.rolloverAmountMinor, currency: period.currency))
    }

    var body: some View {
        Form {
            Section("Quincena") {
                LabeledContent("Inicio") {
                    Text(period.startDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Fin") {
                    Text(period.endDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Moneda") {
                    Text(period.currency.rawValue).foregroundStyle(.secondary)
                }
            }

            Section("Ingreso planeado") {
                amountRow(text: $incomeText)
                Button {
                    apply50_30_20()
                } label: {
                    Label("Aplicar 50/30/20", systemImage: "wand.and.stars")
                }
                .disabled(parsedIncomeMinor <= 0)
            }

            Section("Límites") {
                limitRow(label: "Necesidades", text: $needsText)
                limitRow(label: "Gustos", text: $wantsText)
                limitRow(label: "Ahorro / Deuda", text: $savingsText)
            }

            Section {
                amountRow(text: $rolloverText)
            } header: {
                Text("Sobrante anterior")
            } footer: {
                Text("Sobrante de la quincena anterior que se agrega al disponible.")
            }
        }
        .navigationTitle("Editar quincena")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { save() }
            }
        }
    }

    // MARK: - Rows

    private func limitRow(label: LocalizedStringKey, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(currencySymbol).foregroundStyle(.secondary)
            limitField(text: text)
        }
    }

    @ViewBuilder
    private func limitField(text: Binding<String>) -> some View {
        let field = TextField("0", text: text)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 140)
        #if os(iOS)
        field.keyboardType(.decimalPad)
        #else
        field
        #endif
    }

    private func amountRow(text: Binding<String>) -> some View {
        HStack {
            Text(currencySymbol).foregroundStyle(.secondary)
            limitField(text: text)
        }
    }

    // MARK: - Derived

    private var currencySymbol: String {
        switch period.currency {
        case .COP: "$"
        case .USD: "US$"
        }
    }

    private var parsedIncomeMinor: Int64 {
        parseAmount(incomeText) ?? 0
    }

    // MARK: - Actions

    private func apply50_30_20() {
        let (n, w, s) = BudgetPeriodService.split50_30_20(incomeMinor: parsedIncomeMinor)
        needsText = Self.format(amountMinor: n, currency: period.currency)
        wantsText = Self.format(amountMinor: w, currency: period.currency)
        savingsText = Self.format(amountMinor: s, currency: period.currency)
    }

    private func save() {
        period.incomePlannedMinor = parsedIncomeMinor
        period.needsLimitMinor = parseAmount(needsText) ?? 0
        period.wantsLimitMinor = parseAmount(wantsText) ?? 0
        period.savingsDebtLimitMinor = parseAmount(savingsText) ?? 0
        period.rolloverAmountMinor = parseAmount(rolloverText) ?? 0
        dismiss()
    }

    // MARK: - Parsing / formatting

    private func parseAmount(_ text: String) -> Int64? {
        let trimmed = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        if trimmed.isEmpty { return 0 }
        switch period.currency {
        case .COP:
            return Int64(trimmed)
        case .USD:
            guard let decimal = Decimal(string: trimmed) else { return nil }
            return NSDecimalNumber(decimal: decimal * 100).int64Value
        }
    }

    private static func format(amountMinor: Int64, currency: Currency) -> String {
        switch currency {
        case .COP:
            return String(amountMinor)
        case .USD:
            let dollars = amountMinor / 100
            let remainder = abs(amountMinor % 100)
            return String(format: "%lld.%02lld", dollars, remainder)
        }
    }
}
