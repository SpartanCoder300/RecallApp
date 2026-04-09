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
    @State private var gapState: GapState = .idle
    @State private var rewriteState: RewriteState = .idle
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

            if !isEditing, item.answer != nil {
                rewriteSection
                gapSection
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
        gapState = .idle
        rewriteState = .idle
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
        gapState = .idle
        rewriteState = .idle

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

    // MARK: - Rewrite

    @ViewBuilder
    private var rewriteSection: some View {
        Section {
            switch rewriteState {
            case .idle:
                Button {
                    Task { await performRewrite() }
                } label: {
                    Label("Rewrite answer", systemImage: "wand.and.sparkles")
                }
                .accessibilityLabel("Rewrite answer")
                .accessibilityHint("Uses AI to rewrite your answer with clearer, more concise phrasing")

            case .loading:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Rewriting…")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

            case .preview(let proposed):
                Text(proposed)
                    .font(.body)
                    .textSelection(.enabled)

                Button("Apply rewrite") {
                    applyRewrite(proposed)
                }
                .accessibilityLabel("Apply rewrite")
                .accessibilityHint("Replaces your current answer with the rewritten version")

                Button("Discard", role: .destructive) {
                    rewriteState = .idle
                }
                .accessibilityLabel("Discard rewrite")

            case .error(let message):
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Try again") {
                    Task { await performRewrite() }
                }
                .accessibilityLabel("Retry rewrite")
            }
        } header: {
            Text("Rewrite Answer")
        } footer: {
            if case .preview = rewriteState {
                Text("AI suggestion — same facts, cleaner phrasing. Review before applying.")
            }
        }
    }

    private func performRewrite() async {
        guard let answer = item.answer,
              !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        rewriteState = .loading

        do {
            let proposed = try await AIAnswerService.rewriteAnswer(term: item.term, answer: answer)
            rewriteState = .preview(proposed)
        } catch {
            rewriteState = .error(error.localizedDescription)
        }
    }

    private func applyRewrite(_ proposed: String) {
        item.answer = proposed
        rewriteState = .idle
        gapState = .idle  // gaps are stale against the new answer

        do {
            try modelContext.save()
        } catch {
            errorTitle = "Unable to Save"
            errorMessage = "Please try again."
            showingErrorAlert = true
        }
    }

    // MARK: - Gap suggestions

    @ViewBuilder
    private var gapSection: some View {
        Section {
            switch gapState {
            case .idle:
                Button {
                    Task { await findGaps() }
                } label: {
                    Label("Find knowledge gaps", systemImage: "sparkles")
                }
                .accessibilityLabel("Find knowledge gaps")
                .accessibilityHint("Uses AI to identify sub-concepts missing from your answer")

            case .loading:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Analysing your answer…")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

            case .results(let gaps):
                if gaps.isEmpty {
                    Label("Your answer looks comprehensive.", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                        .font(.body)
                } else {
                    ForEach(gaps, id: \.self) { gap in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.body)
                                .padding(.top, 2)
                                .accessibilityHidden(true)
                            Text(gap)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                Button {
                    Task { await findGaps() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.footnote)
                }
                .foregroundStyle(.secondary)
                .accessibilityLabel("Refresh gap suggestions")

            case .error(let message):
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Try again") {
                    Task { await findGaps() }
                }
                .accessibilityLabel("Retry finding gaps")
            }
        } header: {
            Text("Knowledge Gaps")
        } footer: {
            if case .results = gapState {
                Text("AI suggestions — verify against authoritative sources.")
            }
        }
    }

    private func findGaps() async {
        guard let answer = item.answer,
              !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        gapState = .loading

        do {
            let gaps = try await AIAnswerService.generateGaps(term: item.term, answer: answer)
            gapState = .results(gaps)
        } catch {
            gapState = .error(error.localizedDescription)
        }
    }
}

// MARK: - AI state

private enum RewriteState {
    case idle
    case loading
    case preview(String)
    case error(String)
}

private enum GapState {
    case idle
    case loading
    case results([String])
    case error(String)
}

#Preview {
    NavigationStack {
        ItemDetailScreen(item: PreviewService.itemDetail)
    }
}
