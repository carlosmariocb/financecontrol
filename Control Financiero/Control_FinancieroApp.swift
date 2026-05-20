//
//  Control_FinancieroApp.swift
//  Control Financiero
//
//  Created by Carlos Mario Cardenas Bejarano on 20/05/26.
//

import SwiftUI
import SwiftData

@main
struct Control_FinancieroApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
