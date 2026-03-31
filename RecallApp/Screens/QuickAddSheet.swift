import SwiftUI
import SwiftData

struct QuickAddSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var term = ""
    @State private var note = ""
    @State private var saveErrorMessage = ""
    @State private var showingSaveError = false
    @FocusState private var focus: Field?

    private enum Field { case term, note }

    private var termIsEmpty: Bool {
        term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What did you learn?", text: $term)
                        .focused($focus, equals: .term)
                        .submitLabel(.next)
                        .onSubmit { focus = .note }
                        .accessibilityLabel("Term")

                    TextField("Add a hint or context...", text: $note, axis: .vertical)
                        .focused($focus, equals: .note)
                        .submitLabel(.done)
                        .onSubmit { save() }
                        .lineLimit(1...5)
                        .accessibilityLabel("Hint or context")
                }
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(termIsEmpty)
                        .accessibilityLabel("Save item")
                }
            }
            .alert("Unable to Save Item", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            DispatchQueue.main.async {
                focus = .term
            }
        }
    }

    // MARK: - Save

    private func save() {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else {
            HapticManager.error()
            return
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = RecallItem(
            term: trimmedTerm,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )

        do {
            try modelContext.transaction {
                modelContext.insert(item)
            }
        } catch {
            saveErrorMessage = "Please try again."
            showingSaveError = true
            HapticManager.error()
            return
        }

        HapticManager.success()
        dismiss()
    }
}

// MARK: - Previews

#Preview("Quick Add — Empty") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            QuickAddSheet()
        }
        .modelContainer(PreviewData.container)
}

#Preview("Quick Add — Dark Mode") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            QuickAddSheet()
        }
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
