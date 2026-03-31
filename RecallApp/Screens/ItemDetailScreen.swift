import SwiftUI
import SwiftData

struct ItemDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: RecallItem

    @State private var isEditing = false
    @State private var draftTerm = ""
    @State private var draftNote = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingDiscardConfirmation = false
    @State private var showingErrorAlert = false
    @State private var errorTitle = ""
    @State private var errorMessage = ""

    private var sortedReviews: [Review] {
        (item.reviews ?? []).sorted { $0.reviewedAt > $1.reviewedAt }
    }

    private var trimmedTerm: String {
        draftTerm.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNote: String {
        draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasUnsavedChanges: Bool {
        trimmedTerm != item.term || normalizedCurrentNote != trimmedNote
    }

    private var normalizedCurrentNote: String {
        (item.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            Section {
                if isEditing {
                    TextField("Term", text: $draftTerm, axis: .vertical)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Term")

                    TextEditor(text: $draftNote)
                        .frame(minHeight: 120)
                        .accessibilityLabel("Note")
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
                            Text("No note yet")
                                .font(DT.Typography.body)
                                .foregroundStyle(DT.Color.textSecondary)
                        }
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

    private func syncDrafts() {
        draftTerm = item.term
        draftNote = item.note ?? ""
    }

    private func saveEdits() {
        guard !trimmedTerm.isEmpty else { return }

        item.term = trimmedTerm
        item.note = trimmedNote.isEmpty ? nil : trimmedNote

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
        }
        .padding(.vertical, DT.Spacing.xs)
    }
}

#Preview {
    NavigationStack {
        ItemDetailScreen(item: PreviewService.itemDetail)
    }
}
