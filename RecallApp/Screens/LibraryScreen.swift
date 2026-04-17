import SwiftUI
import SwiftData

struct LibraryScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecallItem.createdAt, order: .reverse) private var allItems: [RecallItem]
    @State private var searchText = ""
    @State private var filter: LibraryFilter = .all
    @State private var showingQuickAdd = false
    @State private var itemPendingDeletion: RecallItem?
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""

    var body: some View {
        NavigationStack {
            LibraryContent(
                items: allItems,
                searchText: $searchText,
                filter: $filter,
                onDelete: { item in
                    itemPendingDeletion = item
                }
            )
            .navigationTitle("Library")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.medium()
                        showingQuickAdd = true
                    } label: {
                        Label("Add Card", systemImage: "plus")
                    }
                    .accessibilityLabel("Add card")
                    .accessibilityHint("Opens the form to create a new recall item")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Filter", selection: $filter) {
                            ForEach(LibraryFilter.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: filter.symbolName)
                    }
                    .accessibilityLabel("Filter items")
                    .accessibilityHint("Changes which library items are shown")
                }
            }
            .sheet(isPresented: $showingQuickAdd) {
                QuickAddSheet()
            }
            .confirmationDialog(
                "Delete this item?",
                isPresented: Binding(
                    get: { itemPendingDeletion != nil },
                    set: { if !$0 { itemPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Item", role: .destructive) {
                    deletePendingItem()
                }
                Button("Cancel", role: .cancel) {
                    itemPendingDeletion = nil
                }
            } message: {
                Text("This removes the item and all of its review history.")
            }
            .alert("Couldn’t Delete Item", isPresented: $showingDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
        }
    }

    private func deletePendingItem() {
        guard let itemPendingDeletion else { return }

        do {
            try RecallItemDeletionService.delete(itemPendingDeletion, from: modelContext)
            self.itemPendingDeletion = nil
        } catch {
            deleteErrorMessage = error.localizedDescription
            showingDeleteError = true
            self.itemPendingDeletion = nil
        }
    }
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case due = "Due"
    case mastered = "Mastered"
    case missed = "Missed"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .all:
            return "line.3.horizontal.decrease.circle"
        case .due:
            return "clock.badge"
        case .mastered:
            return "checkmark.circle"
        case .missed:
            return "exclamationmark.circle"
        }
    }
}

struct LibraryContent: View {
    let items: [RecallItem]
    @Binding var searchText: String
    @Binding var filter: LibraryFilter
    var onDelete: ((RecallItem) -> Void)? = nil

    private var filteredItems: [RecallItem] {
        let searched = items.filter { item in
            guard !searchText.isEmpty else { return true }
            let normalized = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return true }

            let termMatches = item.term.localizedCaseInsensitiveContains(normalized)
            let noteMatches = item.note?.localizedCaseInsensitiveContains(normalized) == true
            return termMatches || noteMatches
        }

        return searched.filter { item in
            switch filter {
            case .all:
                return true
            case .due:
                return item.status == .due
            case .mastered:
                return item.status == .mastered
            case .missed:
                return latestRating(for: item) == .missed
            }
        }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyLibraryState
            } else if filteredItems.isEmpty {
                emptySearchState
            } else {
                List {
                    ForEach(filteredItems) { item in
                        NavigationLink {
                            ItemDetailScreen(item: item)
                        } label: {
                            LibraryRow(item: item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                onDelete?(item)
                            }
                        }
                        .listRowBackground(DT.Color.background)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(DT.Color.background)
    }

    private var emptyLibraryState: some View {
        ContentUnavailableView {
            Label("Your library is empty", systemImage: "books.vertical")
        } description: {
            Text("Add a few recall items and they’ll appear here.")
        }
    }

    private var emptySearchState: some View {
        ContentUnavailableView {
            Label("No matching items", systemImage: "magnifyingglass")
        } description: {
            Text("Try a different search or change the filter.")
        }
    }

    private func latestRating(for item: RecallItem) -> Rating? {
        (item.reviews ?? [])
            .max(by: { $0.reviewedAt < $1.reviewedAt })?
            .rating
    }
}

private struct LibraryRow: View {
    let item: RecallItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DT.Spacing.md) {
            VStack(alignment: .leading, spacing: DT.Spacing.xs) {
                Text(item.term)
                    .font(DT.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DT.Color.textPrimary)
                    .lineLimit(2)

                HStack(spacing: DT.Spacing.xs) {
                    if let collection = item.collection {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(collection.color.color)
                    }
                    Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(DT.Typography.footnote)
                        .foregroundStyle(DT.Color.textSecondary)
                }
            }

            Spacer(minLength: DT.Spacing.sm)

            StatusBadge(status: item.status)
        }
        .padding(.vertical, DT.Spacing.xs)
        .contentShape(Rectangle())
    }
}

#Preview("Library") {
    NavigationStack {
        LibraryContent(
            items: PreviewService.libraryItems,
            searchText: .constant(""),
            filter: .constant(.all),
            onDelete: { _ in }
        )
        .navigationTitle("Library")
    }
}

#Preview("Library Empty") {
    NavigationStack {
        LibraryContent(
            items: [],
            searchText: .constant(""),
            filter: .constant(.all),
            onDelete: { _ in }
        )
        .navigationTitle("Library")
    }
}

#Preview("Library Search Empty") {
    NavigationStack {
        LibraryContent(
            items: PreviewService.libraryItems,
            searchText: .constant("zzz"),
            filter: .constant(.all),
            onDelete: { _ in }
        )
        .navigationTitle("Library")
    }
}
