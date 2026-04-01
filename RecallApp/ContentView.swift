//
//  ContentView.swift
//  RecallApp
//
//  Created by Garrett Spencer on 3/31/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showingQuickAdd = false
    @State private var selectedTab: AppTab = .today

    enum AppTab { case today, library, collections, settings }

    private var showsAddButton: Bool {
        switch selectedTab {
        case .today, .library:
            return true
        case .collections, .settings:
            return false
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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

            if showsAddButton {
                Button {
                    HapticManager.medium()
                    showingQuickAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(DT.Color.accent)
                        .clipShape(Circle())
                        .shadow(color: DT.Color.accent.opacity(0.22), radius: 6, x: 0, y: 2)
                }
                .accessibilityLabel("Add card")
                .padding(.trailing, DT.Spacing.xl)
                .padding(.bottom, DT.Spacing.xxl + DT.Spacing.xl)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.default, value: showsAddButton)
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddSheet()
        }
    }
}

private struct PreviewContentView: View {
    @State private var showingQuickAdd = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView {
                HomeScreenPreview(snapshot: PreviewService.homeSnapshot)
                    .tabItem { Label("Today", systemImage: "house.fill") }

                LibraryContent(
                    items: PreviewService.libraryItems,
                    searchText: .constant(""),
                    filter: .constant(.all)
                )
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }

                CollectionsPlaceholder()
                    .tabItem { Label("Collections", systemImage: "square.stack.fill") }

                SettingsScreen()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }

            Button {
                showingQuickAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(DT.Color.accent)
                    .clipShape(Circle())
                    .shadow(color: DT.Color.accent.opacity(0.22), radius: 6, x: 0, y: 2)
            }
            .accessibilityLabel("Add item")
            .padding(.trailing, DT.Spacing.xl)
            .padding(.bottom, DT.Spacing.xxl + DT.Spacing.xl)
        }
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddSheet(onSavePreview: { _, _ in })
        }
    }
}

#Preview {
    PreviewContentView()
}
