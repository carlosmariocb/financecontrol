import SwiftUI
import SwiftData

struct CategoriesListView: View {
    @Query(sort: \TransactionCategory.name) private var allCategories: [TransactionCategory]

    var body: some View {
        List {
            if topLevel.isEmpty {
                ContentUnavailableView(
                    "Sin categorías",
                    systemImage: "folder",
                    description: Text("Toca + para crear tu primera categoría.")
                )
            } else {
                ForEach(BudgetGroup.allCases, id: \.self) { group in
                    let cats = topLevel.filter { $0.budgetGroup == group }
                    if !cats.isEmpty {
                        Section(label(for: group)) {
                            ForEach(cats) { cat in
                                NavigationLink {
                                    CategoryEditView(editing: cat)
                                } label: {
                                    CategoryListRow(category: cat)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Categorías")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    CategoryEditView(editing: nil)
                } label: {
                    Label("Nueva categoría", systemImage: "plus")
                }
            }
        }
    }

    private var topLevel: [TransactionCategory] {
        allCategories.filter { $0.parent == nil }
    }

    private func label(for group: BudgetGroup) -> String {
        switch group {
        case .needs: "Necesidades"
        case .wants: "Gustos"
        case .savingsDebt: "Ahorro / Deuda"
        case .excluded: "Excluidas"
        }
    }
}

private struct CategoryListRow: View {
    let category: TransactionCategory

    var body: some View {
        HStack {
            Text(category.name)
            Spacer()
            if !category.subcategories.isEmpty {
                Text("\(category.subcategories.count) sub")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
