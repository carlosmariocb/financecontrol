import SwiftUI
import SwiftData

struct GoalsListView: View {
    @Query(sort: \Goal.name) private var goals: [Goal]

    var body: some View {
        List {
            if goals.isEmpty {
                ContentUnavailableView(
                    "Sin metas",
                    systemImage: "target",
                    description: Text("Toca + para crear tu primera meta.")
                )
            } else {
                ForEach(goals) { goal in
                    NavigationLink {
                        GoalEditView(editing: goal)
                    } label: {
                        GoalListRow(goal: goal)
                    }
                }
            }
        }
        .navigationTitle("Metas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    GoalEditView(editing: nil)
                } label: {
                    Label("Nueva meta", systemImage: "plus")
                }
            }
        }
    }
}

private struct GoalListRow: View {
    let goal: Goal

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.name)
                if let deadline = goal.deadline {
                    Text(deadline.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let acc = goal.linkedAccount {
                    Text(acc.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(MoneyFormatter.format(Money(amountMinor: goal.targetAmountMinor, currency: goal.currency)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
