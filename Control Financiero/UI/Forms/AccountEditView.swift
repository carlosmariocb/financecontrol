import SwiftUI
import SwiftData

/// Dual-purpose form for `Account`. `editing == nil` creates a new one; otherwise
/// updates the passed account. Currency is editable only at creation time, since
/// rewriting it later would change the meaning of every historical transaction.
struct AccountEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let editing: Account?

    @State private var name: String
    @State private var type: AccountType
    @State private var currency: Currency
    @State private var initialBalanceText: String
    @State private var includeInTotal: Bool
    @State private var showDeleteConfirm: Bool = false

    init(editing: Account? = nil) {
        self.editing = editing
        if let acc = editing {
            _name = State(initialValue: acc.name)
            _type = State(initialValue: acc.type)
            _currency = State(initialValue: acc.currency)
            _initialBalanceText = State(initialValue: Self.format(amountMinor: acc.initialBalanceMinor, currency: acc.currency))
            _includeInTotal = State(initialValue: acc.includeInTotal)
        } else {
            _name = State(initialValue: "")
            _type = State(initialValue: .bank)
            _currency = State(initialValue: .COP)
            _initialBalanceText = State(initialValue: "0")
            _includeInTotal = State(initialValue: true)
        }
    }

    var body: some View {
        Form {
            identitySection
            typeSection
            balanceSection
            currencySection
            includeSection
            if isEditing {
                deleteSection
            }
        }
        .navigationTitle(isEditing ? (name.isEmpty ? "Cuenta" : name) : "Nueva cuenta")
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
            "¿Eliminar esta cuenta?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) { deleteAccount() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Los movimientos asociados quedarán sin cuenta vinculada.")
        }
    }

    // MARK: - Sections

    private var identitySection: some View {
        Section("Nombre") {
            TextField("Nombre", text: $name)
        }
    }

    private var typeSection: some View {
        Section("Tipo") {
            Picker("Tipo", selection: $type) {
                Text("Banco").tag(AccountType.bank)
                Text("Billetera").tag(AccountType.wallet)
                Text("Efectivo").tag(AccountType.cash)
                Text("Bolsillo").tag(AccountType.pocket)
                Text("Billetera extranjera").tag(AccountType.foreignWallet)
            }
        }
    }

    private var balanceSection: some View {
        Section {
            HStack {
                Text(currencySymbol).foregroundStyle(.secondary)
                balanceField
            }
        } header: {
            Text("Saldo inicial")
        } footer: {
            Text("El saldo desde el cual la app empieza a contar los movimientos.")
        }
    }

    @ViewBuilder
    private var balanceField: some View {
        let field = TextField("0", text: $initialBalanceText)
            .multilineTextAlignment(.trailing)
        #if os(iOS)
        field.keyboardType(.decimalPad)
        #else
        field
        #endif
    }

    private var currencySection: some View {
        Section("Moneda") {
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

    private var includeSection: some View {
        Section {
            Toggle("Incluir en saldo total", isOn: $includeInTotal)
        } footer: {
            Text("Si está desactivado, la cuenta no suma al total mostrado en Inicio.")
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Eliminar cuenta", systemImage: "trash")
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

    private var initialBalanceMinor: Int64 {
        parseAmount(initialBalanceText, currency: currency) ?? 0
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Save / delete

    private func save() {
        if let existing = editing {
            existing.name = name
            existing.type = type
            existing.initialBalanceMinor = initialBalanceMinor
            existing.includeInTotal = includeInTotal
            // currency intentionally not updated
        } else {
            let new = Account(
                name: name, type: type, currency: currency,
                initialBalanceMinor: initialBalanceMinor,
                includeInTotal: includeInTotal
            )
            modelContext.insert(new)
        }
        dismiss()
    }

    private func deleteAccount() {
        guard let acc = editing else { return }
        modelContext.delete(acc)
        dismiss()
    }

    // MARK: - Parsing / formatting

    private func parseAmount(_ text: String, currency: Currency) -> Int64? {
        let trimmed = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        if trimmed.isEmpty { return 0 }
        switch currency {
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
