import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Inicio", systemImage: "house.fill") {
                HomeView()
            }
            Tab("Agregar", systemImage: "plus.circle.fill") {
                AddTransactionView()
            }
            Tab("Presupuesto", systemImage: "chart.pie.fill") {
                BudgetView()
            }
            Tab("Tarjetas", systemImage: "creditcard.fill") {
                CardsDebtsView()
            }
            Tab("Reportes", systemImage: "chart.line.uptrend.xyaxis") {
                ReportsView()
            }
        }
    }
}
