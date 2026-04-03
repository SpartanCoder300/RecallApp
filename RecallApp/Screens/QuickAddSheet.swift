import SwiftUI
import SwiftData

struct QuickAddSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var term = ""
    @State private var note = ""
    @State private var showingAnswerField = false
    @State private var saveErrorMessage = ""
    @State private var showingSaveError = false
    @FocusState private var focus: Field?

    private let onSavePreview: ((String, String?) -> Void)?

    private enum Field { case term, note }

    init(onSavePreview: ((String, String?) -> Void)? = nil) {
        self.onSavePreview = onSavePreview
    }

    private var trimmedTerm: String {
        term.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Term", text: $term, axis: .vertical)
                        .focused($focus, equals: .term)
                        .submitLabel(showingAnswerField ? .next : .done)
                        .onSubmit {
                            if showingAnswerField {
                                focus = .note
                            } else {
                                save()
                            }
                        }
                        .accessibilityLabel("Term")

                    if showingAnswerField {
                        TextField("Answer or context", text: $note, axis: .vertical)
                            .focused($focus, equals: .note)
                            .submitLabel(.done)
                            .onSubmit(save)
                            .accessibilityLabel("Answer or context")
                    }
                }

                if !showingAnswerField {
                    Section {
                        Button {
                            withAnimation {
                                showingAnswerField = true
                            }
                            DispatchQueue.main.async {
                                focus = .note
                            }
                        } label: {
                            Label("Add Context", systemImage: "plus.circle")
                        }
                        .accessibilityLabel("Add context")
                        .accessibilityHint("Shows an optional answer or context field")
                    }
                }
            }
            .navigationTitle("New Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedTerm.isEmpty)
                        .accessibilityLabel("Save card")
                }
            }
            .alert("Unable to Save Item", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
            .onAppear {
                DispatchQueue.main.async {
                    focus = .term
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard !trimmedTerm.isEmpty else {
            HapticManager.error()
            return
        }

        let savedNote = trimmedNote.isEmpty ? nil : trimmedNote

        if let onSavePreview {
            onSavePreview(trimmedTerm, savedNote)
            HapticManager.success()
            dismiss()
            return
        }

        let item = RecallItem(term: trimmedTerm, note: savedNote)

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

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            QuickAddSheet(onSavePreview: { _, _ in })
        }
}
