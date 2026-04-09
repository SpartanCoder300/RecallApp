import SwiftUI
import SwiftData

struct QuickAddSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var term = ""
    @State private var answer = ""
    @State private var note = ""
    @State private var showingHint = false
    @State private var saveErrorMessage = ""
    @State private var showingSaveError = false
    @FocusState private var focus: Field?

    private let onSavePreview: ((String, String?, String?) -> Void)?

    private enum Field { case term, answer, note }

    init(onSavePreview: ((String, String?, String?) -> Void)? = nil) {
        self.onSavePreview = onSavePreview
    }

    private var trimmedTerm: String {
        term.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedAnswer: String {
        answer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Question or concept", text: $term, axis: .vertical)
                        .focused($focus, equals: .term)
                        .submitLabel(.next)
                        .onSubmit { focus = .answer }
                        .accessibilityLabel("Question or concept")

                    TextField("Answer", text: $answer, axis: .vertical)
                        .focused($focus, equals: .answer)
                        .submitLabel(showingHint ? .next : .done)
                        .onSubmit {
                            if showingHint { focus = .note } else { save() }
                        }
                        .accessibilityLabel("Answer")
                }

                if showingHint {
                    Section {
                        TextField("Hint", text: $note, axis: .vertical)
                            .focused($focus, equals: .note)
                            .submitLabel(.done)
                            .onSubmit(save)
                            .accessibilityLabel("Hint")
                    } header: {
                        Text("Hint")
                    } footer: {
                        Text("Shown as context during sessions.")
                    }
                } else {
                    Section {
                        Button {
                            withAnimation { showingHint = true }
                            DispatchQueue.main.async { focus = .note }
                        } label: {
                            Label("Add hint", systemImage: "plus.circle")
                        }
                        .accessibilityLabel("Add hint")
                        .accessibilityHint("Shows an optional hint field displayed during sessions")
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
                DispatchQueue.main.async { focus = .term }
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

        let savedAnswer = trimmedAnswer.isEmpty ? nil : trimmedAnswer
        let savedNote = trimmedNote.isEmpty ? nil : trimmedNote

        if let onSavePreview {
            onSavePreview(trimmedTerm, savedAnswer, savedNote)
            HapticManager.success()
            dismiss()
            return
        }

        let item = RecallItem(term: trimmedTerm, note: savedNote, answer: savedAnswer)

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
            QuickAddSheet(onSavePreview: { _, _, _ in })
        }
}
