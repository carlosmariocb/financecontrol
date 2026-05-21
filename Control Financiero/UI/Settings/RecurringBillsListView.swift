import SwiftUI
import SwiftData

struct RecurringBillsListView: View {
    @Query(sort: \RecurringBill.dueDay) private var bills: [RecurringBill]

    var body: some View {
        List {
            if bills.isEmpty {
                ContentUnavailableView(
                    "Sin facturas",
                    systemImage: "doc.text",
                    description: Text("Toca + para registrar una factura recurrente.")
                )
            } else {
                let (active, inactive) = bills.partitioned(by: { $0.isActive })
                if !active.isEmpty {
                    Section("Activas") {
                        ForEach(active) { bill in row(bill) }
                    }
                }
                if !inactive.isEmpty {
                    Section("Inactivas") {
                        ForEach(inactive) { bill in row(bill) }
                    }
                }
            }
        }
        .navigationTitle("Facturas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    RecurringBillEditView(editing: nil)
                } label: {
                    Label("Nueva factura", systemImage: "plus")
                }
            }
        }
    }

    private func row(_ bill: RecurringBill) -> some View {
        NavigationLink {
            RecurringBillEditView(editing: bill)
        } label: {
            BillRow(bill: bill)
        }
    }
}

private struct BillRow: View {
    let bill: RecurringBill

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                Text("Día \(bill.dueDay)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(MoneyFormatter.format(Money(amountMinor: bill.amountMinor, currency: bill.currency)))
                .font(.subheadline.weight(.semibold))
        }
    }
}

private extension Array {
    /// Splits in two without changing relative order, just like Swift's `partition`
    /// would on a mutable copy but without mutation.
    func partitioned(by isFirst: (Element) -> Bool) -> ([Element], [Element]) {
        var first: [Element] = []
        var rest: [Element] = []
        for el in self {
            if isFirst(el) { first.append(el) } else { rest.append(el) }
        }
        return (first, rest)
    }
}
