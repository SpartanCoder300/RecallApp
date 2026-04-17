import SwiftUI
import SwiftData

struct CollectionsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecallCollection.createdAt, order: .reverse) private var collections: [RecallCollection]
    @State private var showingNewCollection = false
    @State private var collectionToEdit: RecallCollection?
    @State private var collectionToDelete: RecallCollection?

    private let columns = [
        GridItem(.flexible(), spacing: DT.Spacing.md),
        GridItem(.flexible(), spacing: DT.Spacing.md)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if collections.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: DT.Spacing.md) {
                            ForEach(collections) { collection in
                                NavigationLink {
                                    CollectionDetailScreen(collection: collection)
                                } label: {
                                    CollectionCard(collection: collection)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        collectionToEdit = collection
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        collectionToDelete = collection
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } preview: {
                                    CollectionCard(collection: collection)
                                        .frame(width: 180)
                                        .padding(DT.Spacing.sm)
                                }
                            }
                        }
                        .padding(DT.Spacing.md)
                    }
                }
            }
            .background(DT.Color.background)
            .navigationTitle("Collections")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.medium()
                        showingNewCollection = true
                    } label: {
                        Label("New Collection", systemImage: "plus")
                    }
                    .accessibilityLabel("New collection")
                    .accessibilityHint("Creates a new study collection")
                }
            }
            .sheet(isPresented: $showingNewCollection) {
                NewCollectionSheet()
            }
            .sheet(item: $collectionToEdit) { collection in
                EditCollectionSheet(collection: collection)
            }
            .confirmationDialog(
                "Delete \"\(collectionToDelete?.name ?? "")\"?",
                isPresented: Binding(
                    get: { collectionToDelete != nil },
                    set: { if !$0 { collectionToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Collection", role: .destructive) {
                    if let collection = collectionToDelete {
                        modelContext.delete(collection)
                        try? modelContext.save()
                        HapticManager.success()
                    }
                    collectionToDelete = nil
                }
                Button("Cancel", role: .cancel) { collectionToDelete = nil }
            } message: {
                Text("Items in this collection are kept and can still be found in the Library.")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Collections", systemImage: "square.stack")
        } description: {
            Text("Create a collection to group items by study type — like Interview Prep or IoT.")
        } actions: {
            Button("New Collection") {
                HapticManager.medium()
                showingNewCollection = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Collection Card

private struct CollectionCard: View {
    let collection: RecallCollection

    private var itemCount: Int {
        collection.items?.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.sm) {
            HStack {
                Image(systemName: "square.stack.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("\(itemCount)")
                    .font(DT.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer(minLength: DT.Spacing.lg)

            Text(collection.name)
                .font(DT.Typography.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(itemCount == 1 ? "1 item" : "\(itemCount) items")
                .font(DT.Typography.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(DT.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(collection.color.color.gradient)
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
        .contentShape(RoundedRectangle(cornerRadius: DT.Radius.card))
        .accessibilityLabel("\(collection.name), \(itemCount) items")
        .accessibilityHint("Opens this collection")
    }
}

// MARK: - Previews

struct CollectionsPreview: View {
    let collections: [RecallCollection]

    var body: some View {
        let columns = [
            GridItem(.flexible(), spacing: DT.Spacing.md),
            GridItem(.flexible(), spacing: DT.Spacing.md)
        ]
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: DT.Spacing.md) {
                    ForEach(collections) { c in
                        CollectionCard(collection: c)
                    }
                }
                .padding(DT.Spacing.md)
            }
            .navigationTitle("Collections")
        }
    }
}

#Preview("Collections — Populated") {
    CollectionsPreview(collections: PreviewService.sampleCollections)
}

#Preview("Collections — Empty") {
    NavigationStack {
        ContentUnavailableView {
            Label("No Collections", systemImage: "square.stack")
        } description: {
            Text("Create a collection to group items by study type — like Interview Prep or IoT.")
        } actions: {
            Button("New Collection") { }
                .buttonStyle(.borderedProminent)
        }
    }
}
