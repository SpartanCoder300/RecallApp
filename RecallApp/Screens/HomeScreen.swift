import SwiftUI
import SwiftData

struct HomeScreen: View {
    @Query(sort: \RecallItem.createdAt, order: .reverse)
    private var items: [RecallItem]

    @State private var showingQuickAdd = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if items.isEmpty {
                        emptyState
                    } else {
                        itemList
                    }
                }
                .navigationTitle("Daily Recall")
                .navigationBarTitleDisplayMode(.large)

                addButton
            }
        }
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddSheet()
        }
    }

    // MARK: - Subviews

    private var itemList: some View {
        List {
            ForEach(items) { item in
                ItemRow(item: item)
                    .listRowBackground(DT.Color.background)
                    .listRowInsets(EdgeInsets(
                        top: 0,
                        leading: DT.Spacing.lg,
                        bottom: 0,
                        trailing: DT.Spacing.lg
                    ))
            }
        }
        .listStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: items.count)
    }

    private var emptyState: some View {
        VStack(spacing: DT.Spacing.md) {
            Image(systemName: "brain.head.profile")
                .font(DT.Typography.largeTitle)
                .foregroundStyle(DT.Color.textTertiary)

            Text("Nothing to recall yet")
                .font(DT.Typography.headline)
                .foregroundStyle(DT.Color.textSecondary)

            Text("Tap + to capture your first item")
                .font(DT.Typography.subheadline)
                .foregroundStyle(DT.Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DT.Color.background)
    }

    private var addButton: some View {
        Button {
            HapticManager.medium()
            showingQuickAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .tint(DT.Color.accent)
        .padding(.trailing, DT.Spacing.lg)
        .padding(.bottom, DT.Spacing.xl + DT.Spacing.md) // clear home indicator
        .accessibilityLabel("Add item")
    }

}

// MARK: - Previews

#Preview("With items") {
    HomeScreen()
        .modelContainer(PreviewData.container)
}

#Preview("Empty state") {
    HomeScreen()
        .modelContainer(for: RecallItem.self, inMemory: true)
}

#Preview("Dark Mode") {
    HomeScreen()
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
