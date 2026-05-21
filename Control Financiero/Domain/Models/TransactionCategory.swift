import Foundation
import SwiftData

@Model
final class TransactionCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var budgetGroup: BudgetGroup
    var parent: TransactionCategory?
    @Relationship(inverse: \TransactionCategory.parent) var subcategories: [TransactionCategory] = []

    init(
        id: UUID = UUID(),
        name: String,
        budgetGroup: BudgetGroup,
        parent: TransactionCategory? = nil
    ) {
        self.id = id
        self.name = name
        self.budgetGroup = budgetGroup
        self.parent = parent
    }
}
