import SwiftUI

struct CollectionDetailScreen: View {
    let collection: RecallCollection

    @State private var showingSession = false
    @State private var showingEditSheet = false

    private var items: [RecallItem] {
        (collection.items ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    private var dueItems: [RecallItem] {
        items.filter(\.isDue)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                itemList
            }
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .accessibilityLabel("Edit collection")
            }
        }
        .fullScreenCover(isPresented: $showingSession) {
            RecallSessionScreen(items: dueItems)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditCollectionSheet(collection: collection)
        }
    }

    // MARK: - Item List

    private var itemList: some View {
        List {
            headerSection
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

            Section {
                ForEach(items) { item in
                    NavigationLink {
                        ItemDetailScreen(item: item)
                    } label: {
                        CollectionItemRow(item: item)
                    }
                    .listRowBackground(DT.Color.background)
                }
            } header: {
                Text("Items (\(items.count))")
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DT.Spacing.md) {
            HStack(spacing: DT.Spacing.md) {
                statPill(value: "\(items.count)", label: "Items")
                statPill(value: "\(dueItems.count)", label: "Due Now")
            }
            .padding(.top, DT.Spacing.sm)

            startSessionCard
                .padding(.bottom, DT.Spacing.sm)
        }
    }

    private var startSessionCard: some View {
        Button {
            HapticManager.medium()
            showingSession = true
        } label: {
            HStack(spacing: DT.Spacing.md) {
                Image(systemName: dueItems.isEmpty ? "checkmark.circle.fill" : "play.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(dueItems.isEmpty ? DT.Color.textTertiary : .white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(dueItems.isEmpty ? "All Caught Up" : "Start Session")
                        .font(DT.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(dueItems.isEmpty ? DT.Color.textPrimary : .white)

                    Text(dueItems.isEmpty
                         ? "No items due right now"
                         : "\(dueItems.count) item\(dueItems.count == 1 ? "" : "s") due")
                        .font(DT.Typography.subheadline)
                        .foregroundStyle(dueItems.isEmpty ? DT.Color.textSecondary : .white.opacity(0.8))
                }

                Spacer()

                if !dueItems.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(DT.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(DT.Spacing.md)
            .background(
                dueItems.isEmpty
                    ? AnyShapeStyle(DT.Color.surface)
                    : AnyShapeStyle(collection.color.color.gradient),
                in: RoundedRectangle(cornerRadius: DT.Radius.lg)
            )
        }
        .buttonStyle(.plain)
        .disabled(dueItems.isEmpty)
        .accessibilityLabel(dueItems.isEmpty ? "All caught up, nothing due" : "Start session, \(dueItems.count) items due")
        .accessibilityAddTraits(dueItems.isEmpty ? [] : .isButton)
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: DT.Spacing.xs) {
            Text(value)
                .font(DT.Typography.title2)
                .fontWeight(.bold)
                .foregroundStyle(collection.color.color)
            Text(label)
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DT.Spacing.sm)
        .background(DT.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.md))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Items", systemImage: "square.stack")
        } description: {
            Text("Add items to \"\(collection.name)\" from the Library or when creating a new card.")
        }
    }
}

// MARK: - Item Row

private struct CollectionItemRow: View {
    let item: RecallItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DT.Spacing.md) {
            VStack(alignment: .leading, spacing: DT.Spacing.xs) {
                Text(item.term)
                    .font(DT.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DT.Color.textPrimary)
                    .lineLimit(2)

                Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(DT.Typography.footnote)
                    .foregroundStyle(DT.Color.textSecondary)
            }

            Spacer(minLength: DT.Spacing.sm)

            StatusBadge(status: item.status)
        }
        .padding(.vertical, DT.Spacing.xs)
        .contentShape(Rectangle())
    }
}

// MARK: - Previews

#Preview("Detail — With Items") {
    NavigationStack {
        CollectionDetailScreen(collection: PreviewService.sampleCollections[0])
    }
}

#Preview("Detail — Empty") {
    NavigationStack {
        CollectionDetailScreen(collection: PreviewService.sampleCollections[3])
    }
}
