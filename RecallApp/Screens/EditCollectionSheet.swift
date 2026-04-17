import SwiftUI
import SwiftData

struct EditCollectionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let collection: RecallCollection

    @State private var showingDeleteConfirmation = false

    @State private var name: String
    @State private var selectedColor: CollectionColor
    @FocusState private var nameFocused: Bool

    init(collection: RecallCollection) {
        self.collection = collection
        _name = State(initialValue: collection.name)
        _selectedColor = State(initialValue: collection.color)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Collection name", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                        .accessibilityLabel("Collection name")
                } header: {
                    Text("Name")
                }

                Section {
                    ColorSwatchPicker(selectedColor: $selectedColor)
                        .listRowInsets(EdgeInsets(
                            top: DT.Spacing.sm,
                            leading: DT.Spacing.md,
                            bottom: DT.Spacing.sm,
                            trailing: DT.Spacing.md
                        ))
                } header: {
                    Text("Color")
                }

                Section {
                    Button("Delete Collection", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    .accessibilityLabel("Delete collection")
                    .accessibilityHint("Permanently removes this collection. Items are kept.")
                }
            }
            .navigationTitle("Edit Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty)
                        .accessibilityLabel("Save changes")
                }
            }
            .confirmationDialog(
                "Delete \"\(collection.name)\"?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Collection", role: .destructive, action: deleteCollection)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Items in this collection are kept and can still be found in the Library.")
            }
            .onAppear {
                DispatchQueue.main.async { nameFocused = true }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        collection.name = trimmedName
        collection.colorName = selectedColor.rawValue
        try? modelContext.save()
        HapticManager.success()
        dismiss()
    }

    private func deleteCollection() {
        modelContext.delete(collection)
        try? modelContext.save()
        HapticManager.success()
        dismiss()
    }
}
