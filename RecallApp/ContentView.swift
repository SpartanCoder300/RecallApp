//
//  ContentView.swift
//  RecallApp
//
//  Created by Garrett Spencer on 3/31/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: AppTab = .today

    enum AppTab { case today, library, collections, settings }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeScreen()
                .tabItem { Label("Today", systemImage: "house.fill") }
                .tag(AppTab.today)

            LibraryScreen()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                .tag(AppTab.library)

            CollectionsPlaceholder()
                .tabItem { Label("Collections", systemImage: "square.stack.fill") }
                .tag(AppTab.collections)

            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
    }
}

private struct PreviewContentView: View {
    var body: some View {
        TabView {
            HomeScreenPreview(snapshot: PreviewService.homeSnapshot)
                .tabItem { Label("Today", systemImage: "house.fill") }

            NavigationStack {
                LibraryContent(
                    items: PreviewService.libraryItems,
                    searchText: .constant(""),
                    filter: .constant(.all)
                )
                .navigationTitle("Library")
            }
            .tabItem { Label("Library", systemImage: "books.vertical.fill") }

            CollectionsPlaceholder()
                .tabItem { Label("Collections", systemImage: "square.stack.fill") }

            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    PreviewContentView()
}
