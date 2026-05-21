import SwiftUI
import SwiftData

/// Dual-purpose form for `Debt`.
struct DebtEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let editing: Debt?

    @State private var name: String
    @State private var originalText: String
    @State private var currentText: String
    @State private var currency: Currency
    @State private var interestRateText: String
    @State private var paymentText: String
    @State private var dueDay: Int
    @State private var reminderDaysBefore: Int
    @State private var showDeleteConfirm: Bool = false

    init(editing: Debt? = nil) {
        self.editing = editing
        if let debt = editing {
            _name = State(initialValue: debt.name)
            _originalText = State(initialValue: Self.format(amountMinor: debt.originalAmountMinor, currency: debt.currency))
            _currentText = State(initialValue: Self.format(amountMinor: debt.currentBalanceMinor, currency: debt.currency))
            _currency = State(initialValue: debt.currency)
            _interestRateText = State(initialValue: debt.interestRate.map { String($0) } ?? "")
            _paymentText = State(initialValue: Self.format(amountMinor: debt.paymentAmountMinor, currency: debt.currency))
            _dueDay = State(initialValue: debt.dueDay)
            _reminderDaysBefore = State(initialValue: debt.reminderDaysBefore)
        } else {
            _name = State(initialValue: "")
            _originalText = State(initialValue: "0")
            _currentText = State(initialValue: "0")
            _currency = State(initialValue: .COP)
            _interestRateText = State(initialValue: "")
            _paymentText = State(initialValue: "0")
            _dueDay = State(initialValue: 1)
            _reminderDaysBefore = State(initialValue: 3)
        }
    }

    var body: some View {
        Form {
            Section("Nombre") {
                TextField("Nombre", text: $name)
            }
            Section {
                amountRow(label: "Monto original", text: $originalText)
                amountRow(label: "Saldo actual", text: $currentText)
            } header: {
                Text("Saldos")
            }
            Section("Moneda") {
                if isEditing {
                    LabeledContent("Moneda") { Text(currency.rawValue).foregroundStyle(.secondary) }
                } else {
                    Picker("Moneda", selection: $currency) {
                        ForEach(Currency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
            }
            Section("Tasa de interés") {
                HStack {
                    TextField("Sin definir", text: $interestRateText)
                        .multilineTextAlignment(.trailing)
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                    Text("% E.A.").foregroundStyle(.secondary)
                }
            }
            Section {
                amountRow(label: "Cuota mensual", text: $paymentText)
                Stepper(value: $dueDay, in: 1...31) {
                    HStack {
                        Text("Día del mes")
                        Spacer()
                        Text("\(dueDay)").foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Pago")
            }
            Section("Recordatorio") {
                Stepper(value: $reminderDaysBefore, in: 0...30) {
                    HStack {
                        Text("Avisar")
                        Spacer()
                        Text(reminderDaysBefore == 0 ? "El mismo día" : "\(reminderDaysBefore) días antes")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if isEditing {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Eliminar deuda", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(isEditing ? (name.isEmpty ? "Deuda" : name) : "Nueva deuda")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Guardar" : "Crear") { save() }
                    .disabled(!isValid)
            }
        }
        .confirmationDialog(
            "¿Eliminar esta deuda?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) { deleteDebt() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }

    @ViewBuilder
    private func amountRow(label: LocalizedStringKey, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(currencySymbol).foregroundStyle(.secondary)
            let field = TextField("0", text: text)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
            #if os(iOS)
            field.keyboardType(.decimalPad)
            #else
            field
            #endif
        }
    }

    // MARK: - Derived

    private var isEditing: Bool { editing != nil }

    private var currencySymbol: String {
        switch currency {
        case .COP: "$"
        case .USD: "US$"
        }
    }

    private var originalMinor: Int64 { parseAmount(originalText) ?? 0 }
    private var currentMinor: Int64 { parseAmount(currentText) ?? 0 }
    private var paymentMinor: Int64 { parseAmount(paymentText) ?? 0 }

    private var interestRate: Double? {
        let trimmed = interestRateText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if trimmed.isEmpty { return nil }
        return Double(trimmed)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Save / delete

    private func save() {
        if let existing = editing {
            existing.name = name
            existing.originalAmountMinor = originalMinor
            existing.currentBalanceMinor = currentMinor
            existing.interestRate = interestRate
            existing.paymentAmountMinor = paymentMinor
            existing.dueDay = dueDay
            existing.reminderDaysBefore = reminderDaysBefore
        } else {
            let new = Debt(
                name: name,
                originalAmountMinor: originalMinor,
                currentBalanceMinor: currentMinor,
                currency: currency,
                interestRate: interestRate,
                paymentAmountMinor: paymentMinor,
                dueDay: dueDay,
                reminderDaysBefore: reminderDaysBefore
            )
            modelContext.insert(new)
        }
        dismiss()
    }

    private func deleteDebt() {
        guard let debt = editing else { return }
        modelContext.delete(debt)
        dismiss()
    }

    // MARK: - Parsing / formatting

    private func parseAmount(_ text: String) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if trimmed.isEmpty { return 0 }
        switch currency {
        case .COP: return Int64(trimmed)
        case .USD:
            guard let decimal = Decimal(string: trimmed) else { return nil }
            return NSDecimalNumber(decimal: decimal * 100).int64Value
        }
    }

    private static func format(amountMinor: Int64, currency: Currency) -> String {
        switch currency {
        case .COP: return String(amountMinor)
        case .USD:
            let dollars = amountMinor / 100
            let remainder = abs(amountMinor % 100)
            return String(format: "%lld.%02lld", dollars, remainder)
        }
    }
}
