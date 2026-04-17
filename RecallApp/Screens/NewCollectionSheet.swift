import SwiftUI
import SwiftData

struct NewCollectionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedColor: CollectionColor = .blue
    @FocusState private var nameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Interview Prep, IoT", text: $name)
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
            }
            .navigationTitle("New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: save)
                        .disabled(trimmedName.isEmpty)
                        .accessibilityLabel("Create collection")
                }
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
        let collection = RecallCollection(name: trimmedName, color: selectedColor)
        modelContext.insert(collection)
        HapticManager.success()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            NewCollectionSheet()
        }
}
