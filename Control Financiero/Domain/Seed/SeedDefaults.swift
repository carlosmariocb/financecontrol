import Foundation
import SwiftData

enum SeedDefaults {
    static func seedIfEmpty(_ context: ModelContext) throws {
        let existing = try context.fetchCount(FetchDescriptor<Account>())
        guard existing == 0 else { return }

        seedAccounts(context)
        seedCreditCards(context)
        seedCategories(context)
        seedGoals(context)

        try context.save()
    }

    private static func seedAccounts(_ context: ModelContext) {
        let accounts: [Account] = [
            Account(name: "Lulo", type: .bank),
            Account(name: "Lulo Pocket", type: .pocket),
            Account(name: "Nequi", type: .wallet),
            Account(name: "Global66", type: .foreignWallet, currency: .USD),
            Account(name: "Efectivo", type: .cash),
        ]
        for account in accounts { context.insert(account) }
    }

    private static func seedCreditCards(_ context: ModelContext) {
        // TODO: cut-off and due days are placeholders. The user adjusts them in
        // the credit-card onboarding flow shipped in Milestone 3.
        let cards: [CreditCard] = [
            CreditCard(name: "Lulo", bank: "Lulo Bank", cutOffDay: 15, paymentDueDay: 5),
            CreditCard(name: "Nu", bank: "Nu Colombia", cutOffDay: 20, paymentDueDay: 10),
            CreditCard(name: "Davivienda", bank: "Davivienda", cutOffDay: 25, paymentDueDay: 15),
            CreditCard(name: "RappiCard", bank: "Davivienda", cutOffDay: 28, paymentDueDay: 18),
        ]
        for card in cards { context.insert(card) }
    }

    private static func seedCategories(_ context: ModelContext) {
        let tree: [(name: String, group: BudgetGroup, subs: [(String, BudgetGroup)])] = [
            ("Comida", .wants, [
                ("Mercado", .needs),
                ("Restaurantes", .wants),
                ("Café", .wants),
                ("Domicilios", .wants),
            ]),
            ("Vivienda", .needs, [
                ("Arriendo", .needs),
                ("Administración", .needs),
                ("Aseo del hogar", .needs),
            ]),
            ("Transporte", .needs, [
                ("Uber/Yango", .wants),
                ("Transporte público", .needs),
                ("Gasolina", .needs),
                ("Parqueadero", .wants),
            ]),
            ("Servicios", .needs, [
                ("Internet", .needs),
                ("Celular", .needs),
                ("Energía", .needs),
                ("Agua", .needs),
                ("Gas", .needs),
            ]),
            ("Suscripciones", .wants, [
                ("Streaming", .wants),
                ("Software", .wants),
                ("Gimnasio", .wants),
                ("Otros", .wants),
            ]),
            ("Salud", .needs, [
                ("Medicamentos", .needs),
                ("Médico", .needs),
                ("Seguro", .needs),
                ("Bienestar", .wants),
            ]),
            ("Educación", .wants, [
                ("Cursos", .wants),
                ("Libros", .wants),
                ("Matrícula", .wants),
                ("Herramientas", .wants),
            ]),
            ("Ropa", .wants, [
                ("Prendas", .wants),
                ("Zapatos", .wants),
                ("Accesorios", .wants),
            ]),
            ("Entretenimiento", .wants, [
                ("Eventos", .wants),
                ("Juegos", .wants),
                ("Planes", .wants),
                ("Aficiones", .wants),
            ]),
            ("Viajes", .wants, [
                ("Vuelos", .wants),
                ("Hoteles", .wants),
                ("Comida", .wants),
                ("Transporte", .wants),
                ("Actividades", .wants),
            ]),
            ("Deudas", .savingsDebt, [
                ("Intereses de tarjeta", .savingsDebt),
                ("Pago de préstamos", .savingsDebt),
                ("Comisiones", .savingsDebt),
            ]),
            ("Ahorro / Inversiones", .savingsDebt, [
                ("Fondo de emergencia", .savingsDebt),
                ("Meta de viaje", .savingsDebt),
                ("Meta de educación", .savingsDebt),
                ("Inversiones", .savingsDebt),
            ]),
        ]

        for entry in tree {
            let parent = TransactionCategory(name: entry.name, budgetGroup: entry.group)
            context.insert(parent)
            for (subName, subGroup) in entry.subs {
                let sub = TransactionCategory(name: subName, budgetGroup: subGroup, parent: parent)
                context.insert(sub)
            }
        }
    }

    private static func seedGoals(_ context: ModelContext) {
        let goals: [Goal] = [
            Goal(name: "Fondo de emergencia"),
            Goal(name: "Viaje"),
            Goal(name: "Educación"),
            Goal(name: "Inversiones"),
        ]
        for goal in goals { context.insert(goal) }
    }
}
