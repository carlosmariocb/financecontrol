import SwiftUI
import SwiftData

/// Dual-purpose form for `Goal`. Creates a new goal when `editing == nil`, otherwise
/// updates the passed one. Currency is locked once the goal exists.
struct GoalEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.name) private var accounts: [Account]

    let editing: Goal?

    @State private var name: String
    @State private var targetText: String
    @State private var currency: Currency
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var linkedAccount: Account?
    @State private var showDeleteConfirm: Bool = false

    init(editing: Goal? = nil) {
        self.editing = editing
        if let goal = editing {
            _name = State(initialValue: goal.name)
            _targetText = State(initialValue: Self.format(amountMinor: goal.targetAmountMinor, currency: goal.currency))
            _currency = State(initialValue: goal.currency)
            _hasDeadline = State(initialValue: goal.deadline != nil)
            _deadline = State(initialValue: goal.deadline ?? .now)
            _linkedAccount = State(initialValue: goal.linkedAccount)
        } else {
            _name = State(initialValue: "")
            _targetText = State(initialValue: "0")
            _currency = State(initialValue: .COP)
            _hasDeadline = State(initialValue: false)
            _deadline = State(initialValue: .now)
            _linkedAccount = State(initialValue: nil)
        }
    }

    var body: some View {
        Form {
            Section("Nombre") {
                TextField("Nombre", text: $name)
            }
            Section("Monto objetivo") {
                HStack {
                    Text(currencySymbol).foregroundStyle(.secondary)
                    targetField
                }
            }
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
            Section("Fecha límite") {
                Toggle("Con fecha límite", isOn: $hasDeadline)
                if hasDeadline {
                    DatePicker("Fecha", selection: $deadline, displayedComponents: .date)
                }
            }
            Section("Cuenta vinculada") {
                Picker("Cuenta", selection: $linkedAccount) {
                    Text("Sin vincular").tag(Account?.none)
                    ForEach(matchingAccounts) { acc in
                        Text(acc.name).tag(Account?.some(acc))
                    }
                }
            }
            if isEditing {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Eliminar meta", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(isEditing ? (name.isEmpty ? "Meta" : name) : "Nueva meta")
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
            // If the user changes currency at creation time, the previously picked
            // account may no longer match — clear it.
            if let acc = linkedAccount, acc.currency != currency {
                linkedAccount = nil
            }
        }
        .confirmationDialog(
            "¿Eliminar esta meta?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) { deleteGoal() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }

    @ViewBuilder
    private var targetField: some View {
        let field = TextField("0", text: $targetText)
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

    private var targetMinor: Int64 {
        parseAmount(targetText, currency: currency) ?? 0
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Save / delete

    private func save() {
        if let existing = editing {
            existing.name = name
            existing.targetAmountMinor = targetMinor
            existing.deadline = hasDeadline ? deadline : nil
            existing.linkedAccount = linkedAccount
            // currency intentionally locked
        } else {
            let new = Goal(
                name: name,
                targetAmountMinor: targetMinor,
                currency: currency,
                deadline: hasDeadline ? deadline : nil,
                linkedAccount: linkedAccount
            )
            modelContext.insert(new)
        }
        dismiss()
    }

    private func deleteGoal() {
        guard let goal = editing else { return }
        modelContext.delete(goal)
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
