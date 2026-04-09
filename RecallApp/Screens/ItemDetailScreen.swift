import SwiftUI
import SwiftData

struct ItemDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: RecallItem

    @State private var isEditing = false
    @State private var draftTerm = ""
    @State private var draftNote = ""
    @State private var draftAnswer = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingDiscardConfirmation = false
    @State private var showingErrorAlert = false
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @FocusState private var editFocus: EditField?

    private enum EditField { case term, answer, note }

    private var sortedReviews: [Review] {
        (item.reviews ?? []).sorted { $0.reviewedAt > $1.reviewedAt }
    }

    private var trimmedTerm: String {
        draftTerm.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNote: String {
        draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedAnswer: String {
        draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedCurrentNote: String {
        (item.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedCurrentAnswer: String {
        (item.answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasUnsavedChanges: Bool {
        trimmedTerm != item.term
            || trimmedNote != normalizedCurrentNote
            || trimmedAnswer != normalizedCurrentAnswer
    }

    var body: some View {
        List {
            Section("Item") {
                if isEditing {
                    TextField("Term", text: $draftTerm, axis: .vertical)
                        .focused($editFocus, equals: .term)
                        .accessibilityLabel("Term")

                    TextField("Answer", text: $draftAnswer, axis: .vertical)
                        .focused($editFocus, equals: .answer)
                        .accessibilityLabel("Answer")

                    TextField("Hint (optional)", text: $draftNote, axis: .vertical)
                        .focused($editFocus, equals: .note)
                        .accessibilityLabel("Hint")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.term)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .accessibilityAddTraits(.isHeader)

                        if let answer = item.answer, !answer.isEmpty {
                            Text(answer)
                                .font(.body)
                                .textSelection(.enabled)
                        }

                        if let note = item.note, !note.isEmpty {
                            Text(note)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Details") {
                LabeledContent("Status") {
                    StatusBadge(status: item.status)
                }

                LabeledContent("Added") {
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Review History") {
                if sortedReviews.isEmpty {
                    Text("No reviews yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedReviews) { review in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(review.rating.rawValue)
                                .font(.headline)

                            Text(review.reviewedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section {
                Button("Delete Item", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .accessibilityHint("Deletes this item and its review history")
            }
        }
        .navigationTitle("Item")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        cancelEditing()
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        saveEdits()
                    } else {
                        startEditing()
                    }
                }
                .disabled(isEditing && trimmedTerm.isEmpty)
            }
        }
        .confirmationDialog("Delete this item?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Item", role: .destructive, action: deleteItem)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the item and all of its review history.")
        }
        .confirmationDialog("Discard your changes?", isPresented: $showingDiscardConfirmation, titleVisibility: .visible) {
            Button("Discard Changes", role: .destructive) {
                discardChanges()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("Your edits haven’t been saved.")
        }
        .alert(errorTitle, isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear(perform: syncDrafts)
    }

    private func startEditing() {
        syncDrafts()
        isEditing = true
    }

    private func syncDrafts() {
        draftTerm = item.term
        draftAnswer = item.answer ?? ""
        draftNote = item.note ?? ""
    }

    private func saveEdits() {
        guard !trimmedTerm.isEmpty else { return }

        item.term = trimmedTerm
        item.answer = trimmedAnswer.isEmpty ? nil : trimmedAnswer
        item.note = trimmedNote.isEmpty ? nil : trimmedNote

        do {
            try modelContext.save()
            isEditing = false
        } catch {
            errorTitle = "Unable to Save"
            errorMessage = "Please try again."
            showingErrorAlert = true
        }
    }

    private func cancelEditing() {
        if hasUnsavedChanges {
            showingDiscardConfirmation = true
        } else {
            discardChanges()
        }
    }

    private func discardChanges() {
        syncDrafts()
        isEditing = false
    }

    private func deleteItem() {
        do {
            try RecallItemDeletionService.delete(item, from: modelContext)
            dismiss()
        } catch {
            errorTitle = "Unable to Delete"
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        ItemDetailScreen(item: PreviewService.itemDetail)
    }
}
