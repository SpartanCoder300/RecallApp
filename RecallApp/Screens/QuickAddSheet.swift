import SwiftUI
import SwiftData

struct QuickAddSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var term = ""
    @State private var note = ""
    @State private var showingAnswer = false
    @State private var showingRubricFields = false
    @State private var keyFacts = ""
    @State private var acceptedSynonyms = ""
    @State private var commonConfusions = ""
    @State private var saveErrorMessage = ""
    @State private var showingSaveError = false
    @FocusState private var focus: Field?

    private let onSavePreview: ((String, String?, String?, String?, String?) -> Void)?

    private enum Field { case term, note, keyFacts, acceptedSynonyms, commonConfusions }

    init(onSavePreview: ((String, String?, String?, String?, String?) -> Void)? = nil) {
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

                if showingRubricFields {
                    Section("AI Grading Aids") {
                        TextField("Key Facts", text: $keyFacts, axis: .vertical)
                            .focused($focus, equals: .keyFacts)
                            .accessibilityLabel("Key facts")

                        Text("One fact per line. These are the details a strong answer should include.")
                            .font(DT.Typography.footnote)
                            .foregroundStyle(DT.Color.textSecondary)

                        TextField("Accepted Synonyms", text: $acceptedSynonyms, axis: .vertical)
                            .focused($focus, equals: .acceptedSynonyms)
                            .accessibilityLabel("Accepted synonyms")

                        Text("One synonym or alternate phrasing per line.")
                            .font(DT.Typography.footnote)
                            .foregroundStyle(DT.Color.textSecondary)

                        TextField("Common Confusions", text: $commonConfusions, axis: .vertical)
                            .focused($focus, equals: .commonConfusions)
                            .accessibilityLabel("Common confusions")

                        Text("One confusion per line. Add mistakes the AI should treat as meaningfully wrong.")
                            .font(DT.Typography.footnote)
                            .foregroundStyle(DT.Color.textSecondary)
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

                if !showingRubricFields {
                    Section {
                        Button {
                            withAnimation { showingRubricFields = true }
                            DispatchQueue.main.async { focus = .keyFacts }
                        } label: {
                            Label("Add AI Grading Aids", systemImage: "sparkles")
                        }
                        .accessibilityLabel("Add AI grading aids")
                        .accessibilityHint("Expands the sheet to include rubric fields for AI grading")
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
        let trimmedKeyFacts = normalizedMultilineField(keyFacts)
        let trimmedAcceptedSynonyms = normalizedMultilineField(acceptedSynonyms)
        let trimmedCommonConfusions = normalizedMultilineField(commonConfusions)
        let item = RecallItem(
            term: trimmedTerm,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            keyFactsText: trimmedKeyFacts,
            acceptedSynonymsText: trimmedAcceptedSynonyms,
            commonConfusionsText: trimmedCommonConfusions
        )

        if let onSavePreview {
            onSavePreview(
                trimmedTerm,
                trimmedNote.isEmpty ? nil : trimmedNote,
                trimmedKeyFacts,
                trimmedAcceptedSynonyms,
                trimmedCommonConfusions
            )
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

    private func normalizedMultilineField(_ text: String) -> String? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Previews

#Preview("Quick Add — Compact") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            QuickAddSheet(onSavePreview: { _, _, _, _, _ in })
        }
}

#Preview("Quick Add — With Answer") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            QuickAddSheet(onSavePreview: { _, _, _, _, _ in })
        }
}

#Preview("Quick Add — Dark Mode") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            QuickAddSheet(onSavePreview: { _, _, _, _, _ in })
        }
        .preferredColorScheme(.dark)
}
