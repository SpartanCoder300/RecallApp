import SwiftUI
import SwiftData

struct ItemDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: RecallItem

    @State private var isEditing = false
    @State private var draftTerm = ""
    @State private var draftNote = ""
    @State private var draftKeyFacts = ""
    @State private var draftAcceptedSynonyms = ""
    @State private var draftCommonConfusions = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingDiscardConfirmation = false
    @State private var showingErrorAlert = false
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @FocusState private var editFocus: EditField?

    private enum EditField { case term, note, keyFacts, acceptedSynonyms, commonConfusions }

    private var sortedReviews: [Review] {
        (item.reviews ?? []).sorted { $0.reviewedAt > $1.reviewedAt }
    }

    private var trimmedTerm: String {
        draftTerm.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNote: String {
        draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedDraftKeyFacts: String {
        normalizeMultilineField(draftKeyFacts)
    }

    private var normalizedDraftAcceptedSynonyms: String {
        normalizeMultilineField(draftAcceptedSynonyms)
    }

    private var normalizedDraftCommonConfusions: String {
        normalizeMultilineField(draftCommonConfusions)
    }

    private var hasUnsavedChanges: Bool {
        trimmedTerm != item.term ||
        normalizedCurrentNote != trimmedNote ||
        normalizedCurrentKeyFacts != normalizedDraftKeyFacts ||
        normalizedCurrentAcceptedSynonyms != normalizedDraftAcceptedSynonyms ||
        normalizedCurrentCommonConfusions != normalizedDraftCommonConfusions
    }

    private var normalizedCurrentNote: String {
        (item.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedCurrentKeyFacts: String {
        normalizeMultilineField(item.keyFactsText ?? "")
    }

    private var normalizedCurrentAcceptedSynonyms: String {
        normalizeMultilineField(item.acceptedSynonymsText ?? "")
    }

    private var normalizedCurrentCommonConfusions: String {
        normalizeMultilineField(item.commonConfusionsText ?? "")
    }

    var body: some View {
        List {
            Section {
                if isEditing {
                    TextField("Term", text: $draftTerm, axis: .vertical)
                        .focused($editFocus, equals: .term)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Term")

                    TextEditor(text: $draftNote)
                        .focused($editFocus, equals: .note)
                        .frame(minHeight: 120)
                        .accessibilityLabel("Note")

                    TextField("Key Facts", text: $draftKeyFacts, axis: .vertical)
                        .focused($editFocus, equals: .keyFacts)
                        .accessibilityLabel("Key facts")

                    Text("One fact per line.")
                        .font(DT.Typography.footnote)
                        .foregroundStyle(DT.Color.textSecondary)

                    TextField("Accepted Synonyms", text: $draftAcceptedSynonyms, axis: .vertical)
                        .focused($editFocus, equals: .acceptedSynonyms)
                        .accessibilityLabel("Accepted synonyms")

                    Text("One synonym or alternate phrasing per line.")
                        .font(DT.Typography.footnote)
                        .foregroundStyle(DT.Color.textSecondary)

                    TextField("Common Confusions", text: $draftCommonConfusions, axis: .vertical)
                        .focused($editFocus, equals: .commonConfusions)
                        .accessibilityLabel("Common confusions")

                    Text("One confusion per line.")
                        .font(DT.Typography.footnote)
                        .foregroundStyle(DT.Color.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: DT.Spacing.md) {
                        Text(item.term)
                            .font(DT.Typography.title)
                            .fontWeight(.bold)
                            .foregroundStyle(DT.Color.textPrimary)
                            .accessibilityAddTraits(.isHeader)

                        if let note = item.note, !note.isEmpty {
                            Text(note)
                                .font(DT.Typography.body)
                                .foregroundStyle(DT.Color.textPrimary)
                        } else {
                            Button {
                                startEditingNote()
                            } label: {
                                Text("Add answer…")
                                    .font(DT.Typography.body)
                                    .foregroundStyle(DT.Color.accent)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add answer")
                            .accessibilityHint("Opens edit mode focused on the answer field")
                        }

                        rubricSection(title: "Key Facts", entries: item.keyFacts)
                        rubricSection(title: "Accepted Synonyms", entries: item.acceptedSynonyms)
                        rubricSection(title: "Common Confusions", entries: item.commonConfusions)
                    }
                    .padding(.vertical, DT.Spacing.xs)
                }
            } header: {
                Text("Item")
            }

            Section {
                LabeledContent("Status") {
                    StatusBadge(status: item.status)
                }

                LabeledContent("Added") {
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(DT.Color.textSecondary)
                }
            } header: {
                Text("Details")
            }

            Section {
                if sortedReviews.isEmpty {
                    Text("No reviews yet")
                        .foregroundStyle(DT.Color.textSecondary)
                } else {
                    ForEach(sortedReviews) { review in
                        ReviewHistoryRow(review: review)
                    }
                }
            } header: {
                Text("Review History")
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
        .toolbar(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        cancelEditing()
                    }
                    .accessibilityLabel("Cancel editing")
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
                .accessibilityLabel(isEditing ? "Save changes" : "Edit item")
            }
        }
        .confirmationDialog(
            "Delete this item?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Item", role: .destructive, action: deleteItem)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the item and all of its review history.")
        }
        .confirmationDialog(
            "Discard your changes?",
            isPresented: $showingDiscardConfirmation,
            titleVisibility: .visible
        ) {
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

    private func startEditingNote() {
        syncDrafts()
        isEditing = true
        DispatchQueue.main.async { editFocus = .note }
    }

    private func syncDrafts() {
        draftTerm = item.term
        draftNote = item.note ?? ""
        draftKeyFacts = item.keyFactsText ?? ""
        draftAcceptedSynonyms = item.acceptedSynonymsText ?? ""
        draftCommonConfusions = item.commonConfusionsText ?? ""
    }

    private func saveEdits() {
        guard !trimmedTerm.isEmpty else { return }

        item.term = trimmedTerm
        item.note = trimmedNote.isEmpty ? nil : trimmedNote
        item.keyFactsText = normalizedDraftKeyFacts.isEmpty ? nil : normalizedDraftKeyFacts
        item.acceptedSynonymsText = normalizedDraftAcceptedSynonyms.isEmpty ? nil : normalizedDraftAcceptedSynonyms
        item.commonConfusionsText = normalizedDraftCommonConfusions.isEmpty ? nil : normalizedDraftCommonConfusions

        do {
            try modelContext.save()
            isEditing = false
        } catch {
            presentError(title: "Couldn’t Save Changes", error: error)
        }
    }

    private func deleteItem() {
        do {
            try RecallItemDeletionService.delete(item, from: modelContext)
            dismiss()
        } catch {
            presentError(title: "Couldn’t Delete Item", error: error)
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

    private func presentError(title: String, error: Error) {
        errorTitle = title
        errorMessage = error.localizedDescription
        showingErrorAlert = true
    }

    @ViewBuilder
    private func rubricSection(title: String, entries: [String]) -> some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: DT.Spacing.xs) {
                Text(title)
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)

                ForEach(entries, id: \.self) { entry in
                    Label {
                        Text(entry)
                            .font(DT.Typography.body)
                            .foregroundStyle(DT.Color.textPrimary)
                    } icon: {
                        Image(systemName: "circle.fill")
                            .font(DT.Typography.caption2)
                            .foregroundStyle(DT.Color.textTertiary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func normalizeMultilineField(_ text: String) -> String {
        text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

private struct ReviewHistoryRow: View {
    let review: Review

    private var symbolName: String {
        switch review.rating {
        case .easy:
            return "checkmark.circle.fill"
        case .hard:
            return "minus.circle.fill"
        case .forgot:
            return "xmark.circle.fill"
        }
    }

    private var symbolColor: Color {
        switch review.rating {
        case .easy:
            return DT.Color.success
        case .hard:
            return DT.Color.caution
        case .forgot:
            return DT.Color.destructive
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.xs) {
            HStack(spacing: DT.Spacing.sm) {
                Image(systemName: symbolName)
                    .foregroundStyle(symbolColor)
                    .accessibilityHidden(true)

                Text(review.rating.rawValue)
                    .font(DT.Typography.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(review.reviewedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(DT.Typography.footnote)
                    .foregroundStyle(DT.Color.textSecondary)
            }

            if let recalledText = review.recalledText, !recalledText.isEmpty {
                Text(recalledText)
                    .font(DT.Typography.body)
                    .foregroundStyle(DT.Color.textPrimary)
            } else {
                Text("No typed recall saved")
                    .font(DT.Typography.footnote)
                    .foregroundStyle(DT.Color.textSecondary)
            }

            if review.wasAIGraded {
                aiFeedback
            }
        }
        .padding(.vertical, DT.Spacing.xs)
    }

    private var aiFeedback: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.xs) {
            Text("AI Review")
                .font(DT.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DT.Color.accent)

            if let gradingReasoning = review.gradingReasoning, !gradingReasoning.isEmpty {
                Text(gradingReasoning)
                    .font(DT.Typography.footnote)
                    .foregroundStyle(DT.Color.textPrimary)
            }

            if let primaryFeedbackCategory = review.aiPrimaryFeedbackCategory {
                Text(primaryFeedbackCategory.title)
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.accent)
            }

            if let secondaryFeedbackCategory = review.aiSecondaryFeedbackCategory {
                Text(secondaryFeedbackCategory.title)
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }

            Text(coreIdeaText)
                .font(DT.Typography.footnote)
                .foregroundStyle(DT.Color.textSecondary)

            if let missingConcepts = review.aiMissingConcepts, !missingConcepts.isEmpty {
                Text("Missing: \(missingConcepts)")
                    .font(DT.Typography.footnote)
                    .foregroundStyle(DT.Color.textSecondary)
            }

            if let incorrectClaims = review.aiIncorrectClaims, !incorrectClaims.isEmpty {
                Text("Incorrect: \(incorrectClaims)")
                    .font(DT.Typography.footnote)
                    .foregroundStyle(DT.Color.textSecondary)
            }

            if let confidence = review.aiConfidence {
                Text("Confidence: \(confidence.rawValue)")
                    .font(DT.Typography.footnote)
                    .foregroundStyle(DT.Color.textSecondary)
            }

            if review.aiShouldResurfaceSoon == true {
                Text("Flagged for near-term follow-up")
                    .font(DT.Typography.footnote)
                    .foregroundStyle(DT.Color.textSecondary)
            }
        }
        .padding(DT.Spacing.sm)
        .background(DT.Color.surface, in: RoundedRectangle(cornerRadius: DT.Radius.md))
    }

    private var coreIdeaText: String {
        switch review.aiCoreIdeaCorrect {
        case true:
            return "Core idea captured"
        case false:
            return "Core idea missing"
        case nil:
            return "Core idea assessment unavailable"
        }
    }
}

#Preview {
    NavigationStack {
        ItemDetailScreen(item: PreviewService.itemDetail)
    }
}
