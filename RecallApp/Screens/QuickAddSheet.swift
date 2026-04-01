import SwiftUI
import SwiftData

struct QuickAddSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var term = ""
    @State private var note = ""
    @State private var showingAnswer = false
    @State private var saveErrorMessage = ""
    @State private var showingSaveError = false
    @FocusState private var focus: Field?

    private let onSavePreview: ((String, String?) -> Void)?

    private enum Field { case term, note }

    init(onSavePreview: ((String, String?) -> Void)? = nil) {
        self.onSavePreview = onSavePreview
    }

    private var termIsEmpty: Bool {
        term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Prompt", text: $term, axis: .vertical)
                        .focused($focus, equals: .term)
                        .submitLabel(showingAnswer ? .next : .done)
                        .onSubmit { if showingAnswer { focus = .note } }
                        .accessibilityLabel("Prompt")

                    if showingAnswer {
                        TextField("Answer", text: $note, axis: .vertical)
                            .focused($focus, equals: .note)
                            .accessibilityLabel("Answer")
                    }
                }

                if !showingAnswer {
                    Section {
                        Button {
                            withAnimation { showingAnswer = true }
                            DispatchQueue.main.async { focus = .note }
                        } label: {
                            Label("Add Answer", systemImage: "plus.circle")
                        }
                        .accessibilityLabel("Add answer")
                        .accessibilityHint("Expands the sheet to include an answer field")
                    }
                }
            }
            .navigationTitle("New Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(termIsEmpty)
                        .accessibilityLabel("Save card")
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
            DispatchQueue.main.async { focus = .term }
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

        if let onSavePreview {
            onSavePreview(trimmedTerm, trimmedNote.isEmpty ? nil : trimmedNote)
            HapticManager.success()
            dismiss()
            return
        }

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

#Preview("Quick Add — Compact") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            QuickAddSheet(onSavePreview: { _, _ in })
        }
}

#Preview("Quick Add — With Answer") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            QuickAddSheet(onSavePreview: { _, _ in })
        }
}

#Preview("Quick Add — Dark Mode") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            QuickAddSheet(onSavePreview: { _, _ in })
        }
        .preferredColorScheme(.dark)
}
