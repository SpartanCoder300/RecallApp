//
//  RecallAppApp.swift
//  RecallApp
//
//  Created by Garrett Spencer on 3/31/26.
//

import SwiftUI
import SwiftData

@main
struct RecallAppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([RecallItem.self, Review.self, RecallCollection.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [config])
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
