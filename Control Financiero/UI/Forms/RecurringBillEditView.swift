import SwiftUI
import SwiftData

/// Dual-purpose form for `RecurringBill`. New or edit, staged-state.
struct RecurringBillEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

    let editing: RecurringBill?

    @State private var name: String
    @State private var amountText: String
    @State private var currency: Currency
    @State private var dueDay: Int
    @State private var account: Account?
    @State private var category: TransactionCategory?
    @State private var isActive: Bool
    @State private var reminderDaysBefore: Int
    @State private var showDeleteConfirm: Bool = false

    init(editing: RecurringBill? = nil) {
        self.editing = editing
        if let bill = editing {
            _name = State(initialValue: bill.name)
            _amountText = State(initialValue: Self.format(amountMinor: bill.amountMinor, currency: bill.currency))
            _currency = State(initialValue: bill.currency)
            _dueDay = State(initialValue: bill.dueDay)
            _account = State(initialValue: bill.account)
            _category = State(initialValue: bill.category)
            _isActive = State(initialValue: bill.isActive)
            _reminderDaysBefore = State(initialValue: bill.reminderDaysBefore)
        } else {
            _name = State(initialValue: "")
            _amountText = State(initialValue: "0")
            _currency = State(initialValue: .COP)
            _dueDay = State(initialValue: 1)
            _account = State(initialValue: nil)
            _category = State(initialValue: nil)
            _isActive = State(initialValue: true)
            _reminderDaysBefore = State(initialValue: 3)
        }
    }

    var body: some View {
        Form {
            Section("Nombre") {
                TextField("Nombre", text: $name)
            }
            Section("Monto") {
                HStack {
                    Text(currencySymbol).foregroundStyle(.secondary)
                    amountField
                }
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
            Section("Fecha de pago") {
                Stepper(value: $dueDay, in: 1...31) {
                    HStack {
                        Text("Día del mes")
                        Spacer()
                        Text("\(dueDay)").foregroundStyle(.secondary)
                    }
                }
            }
            Section("Cuenta y categoría") {
                Picker("Cuenta", selection: $account) {
                    Text("Sin vincular").tag(Account?.none)
                    ForEach(matchingAccounts) { acc in
                        Text(acc.name).tag(Account?.some(acc))
                    }
                }
                Picker("Categoría", selection: $category) {
                    Text("Sin categoría").tag(TransactionCategory?.none)
                    ForEach(categories) { cat in
                        Text(categoryLabel(cat)).tag(TransactionCategory?.some(cat))
                    }
                }
            }
            Section {
                Toggle("Activo", isOn: $isActive)
                Stepper(value: $reminderDaysBefore, in: 0...30) {
                    HStack {
                        Text("Recordatorio")
                        Spacer()
                        Text(reminderDaysBefore == 0 ? "El mismo día" : "\(reminderDaysBefore) días antes")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Recordatorios")
            }
            if isEditing {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Eliminar factura", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(isEditing ? (name.isEmpty ? "Factura" : name) : "Nueva factura")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Guardar" : "Crear") { save() }
                    .disabled(!isValid)
            }
        }
        .onChange(of: currency) { _, _ in
            if let acc = account, acc.currency != currency { account = nil }
        }
        .confirmationDialog(
            "¿Eliminar esta factura?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) { deleteBill() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }

    @ViewBuilder
    private var amountField: some View {
        let field = TextField("0", text: $amountText)
            .multilineTextAlignment(.trailing)
        #if os(iOS)
        field.keyboardType(.decimalPad)
        #else
        field
        #endif
    }

    // MARK: - Derived

    private var isEditing: Bool { editing != nil }

    private var currencySymbol: String {
        switch currency {
        case .COP: "$"
        case .USD: "US$"
        }
    }

    private var matchingAccounts: [Account] {
        accounts.filter { $0.currency == currency }
    }

    private var amountMinor: Int64 {
        parseAmount(amountText, currency: currency) ?? 0
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func categoryLabel(_ cat: TransactionCategory) -> String {
        if let parent = cat.parent { return "\(parent.name) › \(cat.name)" }
        return cat.name
    }

    // MARK: - Save / delete

    private func save() {
        if let existing = editing {
            existing.name = name
            existing.amountMinor = amountMinor
            existing.dueDay = dueDay
            existing.account = account
            existing.category = category
            existing.isActive = isActive
            existing.reminderDaysBefore = reminderDaysBefore
        } else {
            let new = RecurringBill(
                name: name, amountMinor: amountMinor, currency: currency,
                dueDay: dueDay, account: account, category: category,
                isActive: isActive, reminderDaysBefore: reminderDaysBefore
            )
            modelContext.insert(new)
        }
        dismiss()
    }

    private func deleteBill() {
        guard let bill = editing else { return }
        modelContext.delete(bill)
        dismiss()
    }

    // MARK: - Parsing / formatting

    private func parseAmount(_ text: String, currency: Currency) -> Int64? {
        let trimmed = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
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
