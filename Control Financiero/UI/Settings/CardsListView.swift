import SwiftUI
import SwiftData

struct CardsListView: View {
    @Query(sort: \CreditCard.name) private var cards: [CreditCard]

    var body: some View {
        List {
            if cards.isEmpty {
                ContentUnavailableView(
                    "Sin tarjetas",
                    systemImage: "creditcard",
                    description: Text("Toca + para crear tu primera tarjeta.")
                )
            } else {
                ForEach(cards) { card in
                    NavigationLink {
                        CreditCardEditView(editing: card)
                    } label: {
                        CardListRow(card: card)
                    }
                }
            }
        }
        .navigationTitle("Tarjetas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    CreditCardEditView(editing: nil)
                } label: {
                    Label("Nueva tarjeta", systemImage: "plus")
                }
            }
        }
    }
}

private struct CardListRow: View {
    let card: CreditCard

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.body)
                Text(card.bank)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Corte \(card.cutOffDay) · Pago \(card.paymentDueDay)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(card.currency.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
