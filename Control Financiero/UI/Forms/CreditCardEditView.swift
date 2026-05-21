import SwiftUI
import SwiftData

/// Dual-purpose form: creates a new `CreditCard` when `editing == nil`, otherwise
/// updates the passed card. State is staged in `@State` so cancelling (back-swipe
/// without saving) leaves the store untouched in new-mode.
struct CreditCardEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let editing: CreditCard?

    @State private var name: String
    @State private var bank: String
    @State private var cutOffDay: Int
    @State private var paymentDueDay: Int
    @State private var limitText: String
    @State private var currency: Currency
    @State private var showDeleteConfirm: Bool = false

    init(editing: CreditCard? = nil) {
        self.editing = editing
        if let card = editing {
            _name = State(initialValue: card.name)
            _bank = State(initialValue: card.bank)
            _cutOffDay = State(initialValue: card.cutOffDay)
            _paymentDueDay = State(initialValue: card.paymentDueDay)
            _limitText = State(initialValue: card.limitMinor.map { Self.format(amountMinor: $0, currency: card.currency) } ?? "")
            _currency = State(initialValue: card.currency)
        } else {
            _name = State(initialValue: "")
            _bank = State(initialValue: "")
            _cutOffDay = State(initialValue: 15)
            _paymentDueDay = State(initialValue: 5)
            _limitText = State(initialValue: "")
            _currency = State(initialValue: .COP)
        }
    }

    var body: some View {
        Form {
            identitySection
            cycleSection
            limitSection
            currencySection
            if isEditing {
                deleteSection
            }
        }
        .navigationTitle(isEditing ? (name.isEmpty ? "Tarjeta" : name) : "Nueva tarjeta")
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
            "¿Eliminar esta tarjeta?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) { deleteCard() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Los movimientos asociados quedarán sin tarjeta vinculada.")
        }
    }

    // MARK: - Sections

    private var identitySection: some View {
        Section("Identificación") {
            TextField("Nombre", text: $name)
            TextField("Banco", text: $bank)
        }
    }

    private var cycleSection: some View {
        Section {
            Stepper(value: $cutOffDay, in: 1...31) {
                HStack {
                    Text("Día de corte")
                    Spacer()
                    Text("\(cutOffDay)").foregroundStyle(.secondary)
                }
            }
            Stepper(value: $paymentDueDay, in: 1...31) {
                HStack {
                    Text("Día de pago")
                    Spacer()
                    Text("\(paymentDueDay)").foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Ciclo de facturación")
        } footer: {
            Text("Días del mes en que la tarjeta corta y vence.")
        }
    }

    private var limitSection: some View {
        Section("Cupo") {
            HStack {
                Text(currencySymbol).foregroundStyle(.secondary)
                limitField
                if !limitText.isEmpty {
                    Button {
                        limitText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var limitField: some View {
        let field = TextField("Sin definir", text: $limitText)
            .multilineTextAlignment(.trailing)
        #if os(iOS)
        field.keyboardType(.decimalPad)
        #else
        field
        #endif
    }

    private var currencySection: some View {
        Section("Moneda") {
            // Currency is editable when creating; locked once the card exists, because
            // changing it would silently rewrite the meaning of every historical
            // transaction on this card.
            if isEditing {
                LabeledContent("Moneda") {
                    Text(currency.rawValue).foregroundStyle(.secondary)
                }
            } else {
                Picker("Moneda", selection: $currency) {
                    ForEach(Currency.allCases, id: \.self) { c in
                        Text(c.rawValue).tag(c)
                    }
                }
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Eliminar tarjeta", systemImage: "trash")
            }
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

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var limitMinor: Int64? {
        let trimmed = limitText
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        if trimmed.isEmpty { return nil }
        switch currency {
        case .COP:
            return Int64(trimmed)
        case .USD:
            guard let decimal = Decimal(string: trimmed), decimal >= 0 else { return nil }
            return NSDecimalNumber(decimal: decimal * 100).int64Value
        }
    }

    // MARK: - Save / delete

    private func save() {
        if let existing = editing {
            existing.name = name
            existing.bank = bank
            existing.cutOffDay = cutOffDay
            existing.paymentDueDay = paymentDueDay
            existing.limitMinor = limitMinor
            // currency intentionally not updated
        } else {
            let new = CreditCard(
                name: name, bank: bank,
                cutOffDay: cutOffDay, paymentDueDay: paymentDueDay,
                limitMinor: limitMinor, currency: currency
            )
            modelContext.insert(new)
        }
        dismiss()
    }

    private func deleteCard() {
        guard let card = editing else { return }
        modelContext.delete(card)
        dismiss()
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
