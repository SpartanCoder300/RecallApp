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
    private let sharedModelContainer: ModelContainer = {
        let schema = Schema([RecallItem.self, Review.self, RecallCollection.self])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
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
