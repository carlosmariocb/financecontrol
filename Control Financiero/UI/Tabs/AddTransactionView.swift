import SwiftUI
import SwiftData

/// Root view of the "Agregar" tab — hosts a fresh `TransactionFormView` in its
/// own navigation stack. For editing an existing transaction, push
/// `TransactionFormView(editing:)` onto another stack instead.
struct AddTransactionView: View {
    var body: some View {
        NavigationStack {
            TransactionFormView(editing: nil)
        }
    }
}

/// Dual-purpose form: creates a new transaction when `editing == nil`, otherwise
/// edits the passed-in `Transaction` in place. Designed to be pushed onto any
/// NavigationStack — does NOT wrap itself in one.
struct TransactionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \CreditCard.name) private var cards: [CreditCard]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

    let editing: Transaction?

    @State private var type: TransactionType
    @State private var amountText: String
    @State private var date: Date
    @State private var sourceAccount: Account?
    @State private var destinationAccount: Account?
    @State private var card: CreditCard?
    @State private var category: TransactionCategory?
    @State private var details: String
    @State private var installments: Int
    @State private var inlineError: String?
    @State private var justSaved: Bool = false
    @State private var showDeleteConfirm: Bool = false

    init(editing: Transaction? = nil) {
        self.editing = editing
        if let tx = editing {
            _type = State(initialValue: tx.type)
            _amountText = State(initialValue: Self.formatAmountForEdit(amountMinor: tx.amountMinor, currency: tx.currency))
            _date = State(initialValue: tx.date)
            _sourceAccount = State(initialValue: tx.account)
            _destinationAccount = State(initialValue: tx.toAccount)
            _card = State(initialValue: tx.creditCard)
            _category = State(initialValue: tx.category)
            _details = State(initialValue: tx.details ?? "")
            _installments = State(initialValue: tx.installmentPlan?.numberOfInstallments ?? 1)
        } else {
            _type = State(initialValue: .expense)
            _amountText = State(initialValue: "")
            _date = State(initialValue: .now)
            _sourceAccount = State(initialValue: nil)
            _destinationAccount = State(initialValue: nil)
            _card = State(initialValue: nil)
            _category = State(initialValue: nil)
            _details = State(initialValue: "")
            _installments = State(initialValue: 1)
        }
    }

    var body: some View {
        Form {
            typeSection
            amountSection
            accountSection
            if showsCategory {
                categorySection
            }
            if type == .creditCardPurchase {
                installmentsSection
            }
            detailsSection
            dateSection
            if let inlineError {
                Section {
                    Text(inlineError)
                        .foregroundStyle(.red)
                }
            }
            if justSaved {
                Section {
                    Label("Guardado", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            if isEditing {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Editar movimiento" : "Nuevo movimiento")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Actualizar" : "Guardar") { save() }
                    .disabled(!isValid)
            }
        }
        .onAppear { primeDefaults() }
        .onChange(of: type) { _, newValue in
            inlineError = nil
            switch newValue {
            case .transfer:
                category = nil
                card = nil
            case .creditCardPurchase:
                destinationAccount = nil
                sourceAccount = nil
                primeCardIfNeeded()
            case .creditCardPayment:
                destinationAccount = nil
                category = nil
                primeCardIfNeeded()
                primeAccountIfNeeded()
            case .income, .expense:
                destinationAccount = nil
                card = nil
                installments = 1
                primeAccountIfNeeded()
            case .savingsAllocation, .debtPayment, .feeOrInterest:
                break
            }
        }
        .onChange(of: sourceAccount?.id) { _, _ in
            if let source = sourceAccount,
               let dest = destinationAccount,
               dest.id == source.id || dest.currency != source.currency {
                destinationAccount = nil
            }
        }
        .confirmationDialog(
            "¿Eliminar este movimiento?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) { delete() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }

    // MARK: - Sections

    private var typeSection: some View {
        Section {
            Picker("Tipo", selection: $type) {
                Label("Ingreso", systemImage: "arrow.down.circle").tag(TransactionType.income)
                Label("Gasto", systemImage: "arrow.up.circle").tag(TransactionType.expense)
                Label("Transferencia", systemImage: "arrow.left.arrow.right.circle").tag(TransactionType.transfer)
                Label("Compra con tarjeta", systemImage: "creditcard").tag(TransactionType.creditCardPurchase)
                Label("Pago de tarjeta", systemImage: "creditcard.fill").tag(TransactionType.creditCardPayment)
            }
            .pickerStyle(.menu)
        }
    }

    private var amountSection: some View {
        Section("Monto") {
            HStack {
                Text(currencySymbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
                amountField
            }
        }
    }

    @ViewBuilder
    private var amountField: some View {
        let field = TextField("0", text: $amountText)
            .font(.title2)
            .multilineTextAlignment(.trailing)
        #if os(iOS)
        field.keyboardType(.decimalPad)
        #else
        field
        #endif
    }

    @ViewBuilder
    private var accountSection: some View {
        switch type {
        case .income, .expense:
            Section("Cuenta") {
                accountPicker(label: "Cuenta", selection: $sourceAccount, options: accounts)
            }
        case .transfer:
            Section("Cuentas") {
                accountPicker(label: "Cuenta origen", selection: $sourceAccount, options: accounts)
                accountPicker(label: "Cuenta destino", selection: $destinationAccount, options: transferDestinations)
            }
        case .creditCardPurchase:
            Section("Tarjeta") {
                cardPicker
            }
        case .creditCardPayment:
            Section("Pago") {
                accountPicker(label: "Cuenta origen", selection: $sourceAccount, options: accounts)
                cardPicker
            }
        case .savingsAllocation, .debtPayment, .feeOrInterest:
            EmptyView()
        }
    }

    private func accountPicker(label: LocalizedStringKey, selection: Binding<Account?>, options: [Account]) -> some View {
        Picker(label, selection: selection) {
            Text("—").tag(Account?.none)
            ForEach(options) { account in
                Text(account.name).tag(Account?.some(account))
            }
        }
    }

    private var cardPicker: some View {
        Picker("Tarjeta", selection: $card) {
            Text("—").tag(CreditCard?.none)
            ForEach(cards) { c in
                Text(c.name).tag(CreditCard?.some(c))
            }
        }
    }

    private var categorySection: some View {
        Section("Categoría") {
            Picker("Categoría", selection: $category) {
                Text("Sin categoría").tag(TransactionCategory?.none)
                ForEach(categories) { cat in
                    Text(categoryLabel(cat)).tag(TransactionCategory?.some(cat))
                }
            }
        }
    }

    private var installmentsSection: some View {
        Section("Cuotas") {
            // Editing the cuotas count of an existing card purchase would desync the
            // linked InstallmentPlan — disable the stepper in edit mode to keep the
            // plan and the transaction consistent. (Delete + recreate to change cuotas.)
            Stepper(value: $installments, in: 1...36) {
                HStack {
                    Text("Cuotas")
                    Spacer()
                    Text("\(installments)")
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(isEditing)

            if installments > 1, let minor = amountMinor, let currency = transactionCurrency {
                let monthly = Money(amountMinor: minor / Int64(installments), currency: currency)
                HStack {
                    Text("Cuota mensual")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(MoneyFormatter.format(monthly))
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
            }
        }
    }

    private var detailsSection: some View {
        Section("Detalles") {
            TextField("Notas", text: $details, axis: .vertical)
                .lineLimit(1...3)
        }
    }

    private var dateSection: some View {
        Section {
            DatePicker("Fecha", selection: $date, displayedComponents: .date)
        }
    }

    // MARK: - Derived state

    private var isEditing: Bool { editing != nil }

    private var showsCategory: Bool {
        switch type {
        case .expense, .income, .creditCardPurchase: true
        case .transfer, .creditCardPayment, .savingsAllocation, .debtPayment, .feeOrInterest: false
        }
    }

    private var transferDestinations: [Account] {
        guard let source = sourceAccount else { return [] }
        return accounts.filter { $0.id != source.id && $0.currency == source.currency }
    }

    private var transactionCurrency: Currency? {
        switch type {
        case .creditCardPurchase, .creditCardPayment:
            return card?.currency
        case .income, .expense, .transfer, .savingsAllocation, .debtPayment, .feeOrInterest:
            return sourceAccount?.currency
        }
    }

    private var currencySymbol: String {
        switch transactionCurrency ?? .COP {
        case .COP: "$"
        case .USD: "US$"
        }
    }

    private var amountMinor: Int64? {
        let trimmed = amountText
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty else { return nil }
        let currency = transactionCurrency ?? .COP
        switch currency {
        case .COP:
            guard let value = Int64(trimmed), value > 0 else { return nil }
            return value
        case .USD:
            guard let decimal = Decimal(string: trimmed), decimal > 0 else { return nil }
            let cents = NSDecimalNumber(decimal: decimal * 100).int64Value
            return cents > 0 ? cents : nil
        }
    }

    private var isValid: Bool {
        guard amountMinor != nil else { return false }
        switch type {
        case .income, .expense:
            return sourceAccount != nil
        case .transfer:
            guard let source = sourceAccount,
                  let dest = destinationAccount,
                  dest.id != source.id,
                  dest.currency == source.currency
            else { return false }
            return true
        case .creditCardPurchase:
            return card != nil && installments >= 1
        case .creditCardPayment:
            guard let source = sourceAccount, let chosen = card else { return false }
            return source.currency == chosen.currency
        case .savingsAllocation, .debtPayment, .feeOrInterest:
            return false
        }
    }

    private func categoryLabel(_ cat: TransactionCategory) -> String {
        if let parent = cat.parent { return "\(parent.name) › \(cat.name)" }
        return cat.name
    }

    private func primeDefaults() {
        // Only auto-pick defaults when creating a new transaction. Edit mode is
        // pre-populated from the source object, so we must not overwrite.
        guard !isEditing else { return }
        primeAccountIfNeeded()
        primeCardIfNeeded()
    }

    private func primeAccountIfNeeded() {
        if sourceAccount == nil {
            sourceAccount = accounts.first
        }
    }

    private func primeCardIfNeeded() {
        if card == nil {
            card = cards.first
        }
    }

    private static func formatAmountForEdit(amountMinor: Int64, currency: Currency) -> String {
        switch currency {
        case .COP:
            return String(amountMinor)
        case .USD:
            let cents = amountMinor
            let dollars = cents / 100
            let remainder = abs(cents % 100)
            return String(format: "%lld.%02lld", dollars, remainder)
        }
    }

    // MARK: - Save / update / delete

    private func save() {
        guard let minor = amountMinor else { return }

        if let editingTx = editing {
            updateExisting(editingTx, minor: minor)
            dismiss()
            return
        }

        switch type {
        case .income, .expense:
            guard let source = sourceAccount else { return }
            insertSimple(minor: minor, currency: source.currency, account: source)

        case .transfer:
            guard let source = sourceAccount, let dest = destinationAccount, dest.id != source.id else {
                inlineError = String(localized: "Origen y destino deben ser cuentas distintas")
                return
            }
            insertTransfer(minor: minor, source: source, dest: dest)

        case .creditCardPurchase:
            guard let chosenCard = card else { return }
            insertCardPurchase(minor: minor, card: chosenCard)

        case .creditCardPayment:
            guard let source = sourceAccount, let chosenCard = card, source.currency == chosenCard.currency else {
                inlineError = String(localized: "La cuenta y la tarjeta deben tener la misma moneda")
                return
            }
            insertCardPayment(minor: minor, source: source, card: chosenCard)

        case .savingsAllocation, .debtPayment, .feeOrInterest:
            return
        }
        resetAfterSave()
    }

    /// Mutates the existing transaction in place. Type changes are honored, and
    /// fields that don't apply to the new type are cleared so the data stays
    /// internally consistent. The linked `InstallmentPlan` is preserved as-is.
    private func updateExisting(_ tx: Transaction, minor: Int64) {
        tx.type = type
        tx.amountMinor = minor
        tx.date = date
        tx.details = details.isEmpty ? nil : details
        tx.updatedAt = .now

        switch type {
        case .income, .expense:
            guard let source = sourceAccount else { return }
            tx.currency = source.currency
            tx.account = source
            tx.toAccount = nil
            tx.creditCard = nil
            tx.category = category
        case .transfer:
            guard let source = sourceAccount, let dest = destinationAccount else { return }
            tx.currency = source.currency
            tx.account = source
            tx.toAccount = dest
            tx.creditCard = nil
            tx.category = nil
        case .creditCardPurchase:
            guard let chosenCard = card else { return }
            tx.currency = chosenCard.currency
            tx.account = nil
            tx.toAccount = nil
            tx.creditCard = chosenCard
            tx.category = category
        case .creditCardPayment:
            guard let source = sourceAccount, let chosenCard = card else { return }
            tx.currency = chosenCard.currency
            tx.account = source
            tx.toAccount = nil
            tx.creditCard = chosenCard
            tx.category = nil
        case .savingsAllocation, .debtPayment, .feeOrInterest:
            break
        }
    }

    private func delete() {
        guard let editingTx = editing else { return }
        if let plan = editingTx.installmentPlan {
            modelContext.delete(plan)
        }
        modelContext.delete(editingTx)
        dismiss()
    }

    private func insertSimple(minor: Int64, currency: Currency, account: Account) {
        let tx = Transaction(
            date: date, type: type, amountMinor: minor, currency: currency,
            account: account, category: category,
            details: details.isEmpty ? nil : details, source: .manual
        )
        modelContext.insert(tx)
    }

    private func insertTransfer(minor: Int64, source: Account, dest: Account) {
        let tx = Transaction(
            date: date, type: .transfer, amountMinor: minor, currency: source.currency,
            account: source, toAccount: dest,
            details: details.isEmpty ? nil : details, source: .manual
        )
        modelContext.insert(tx)
    }

    private func insertCardPurchase(minor: Int64, card: CreditCard) {
        let plan: InstallmentPlan?
        if installments > 1 {
            let monthly = minor / Int64(installments)
            plan = InstallmentPlan(
                totalAmountMinor: minor, numberOfInstallments: installments,
                remainingInstallments: installments, monthlyAmountMinor: monthly,
                creditCard: card, startDate: date, currency: card.currency
            )
            if let plan { modelContext.insert(plan) }
        } else {
            plan = nil
        }

        let tx = Transaction(
            date: date, type: .creditCardPurchase, amountMinor: minor, currency: card.currency,
            creditCard: card, category: category,
            details: details.isEmpty ? nil : details,
            installmentPlan: plan, source: .manual
        )
        modelContext.insert(tx)
    }

    private func insertCardPayment(minor: Int64, source: Account, card: CreditCard) {
        let tx = Transaction(
            date: date, type: .creditCardPayment, amountMinor: minor, currency: card.currency,
            account: source, creditCard: card,
            details: details.isEmpty ? nil : details, source: .manual
        )
        modelContext.insert(tx)
    }

    private func resetAfterSave() {
        amountText = ""
        details = ""
        category = nil
        installments = 1
        date = .now
        inlineError = nil
        justSaved = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            justSaved = false
        }
    }
}
