import SwiftUI
import SwiftData

/// Dual-purpose form for `TransactionCategory`. Creates a new top-level category when
/// `editing == nil`, otherwise updates the passed one.
///
/// M3 polish scope: only edits name and budget group. Reparenting and subcategory
/// management are out of scope — categories edited here are top-level. The existing
/// parent relationship is preserved on save.
struct CategoryEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let editing: TransactionCategory?

    @State private var name: String
    @State private var budgetGroup: BudgetGroup
    @State private var showDeleteConfirm: Bool = false

    init(editing: TransactionCategory? = nil) {
        self.editing = editing
        if let cat = editing {
            _name = State(initialValue: cat.name)
            _budgetGroup = State(initialValue: cat.budgetGroup)
        } else {
            _name = State(initialValue: "")
            _budgetGroup = State(initialValue: .wants)
        }
    }

    var body: some View {
        Form {
            Section("Nombre") {
                TextField("Nombre", text: $name)
            }
            Section {
                Picker("Grupo", selection: $budgetGroup) {
                    Text("Necesidades").tag(BudgetGroup.needs)
                    Text("Gustos").tag(BudgetGroup.wants)
                    Text("Ahorro / Deuda").tag(BudgetGroup.savingsDebt)
                    Text("Excluida").tag(BudgetGroup.excluded)
                }
            } header: {
                Text("Grupo de presupuesto")
            } footer: {
                Text("Determina si la categoría cuenta como necesidad, gusto, ahorro/deuda, o queda fuera del 50/30/20.")
            }
            if let editing, !editing.subcategories.isEmpty {
                Section("Subcategorías") {
                    ForEach(editing.subcategories) { sub in
                        Text(sub.name)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if isEditing {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Eliminar categoría", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(isEditing ? (name.isEmpty ? "Categoría" : name) : "Nueva categoría")
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
            "¿Eliminar esta categoría?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) { deleteCategory() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Las subcategorías y los movimientos asociados quedarán sin categoría.")
        }
    }

    private var isEditing: Bool { editing != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        if let existing = editing {
            existing.name = name
            existing.budgetGroup = budgetGroup
        } else {
            let new = TransactionCategory(name: name, budgetGroup: budgetGroup)
            modelContext.insert(new)
        }
        dismiss()
    }

    private func deleteCategory() {
        guard let cat = editing else { return }
        // Subcategories become orphaned (parent = nil) — that's fine because the
        // relationship is optional. They remain as top-level categories.
        for sub in cat.subcategories {
            sub.parent = nil
        }
        modelContext.delete(cat)
        dismiss()
    }
}
