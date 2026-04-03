import SwiftUI
import SwiftData

struct RecallSessionScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let items: [RecallItem]

    @State private var queue: [RecallItem] = []
    @State private var completedCount = 0
    @State private var revealedAnswer: String?
    @State private var isGeneratingAnswer = false
    @State private var generationErrorMessage = ""
    @State private var showingGenerationError = false
    @State private var showingExitConfirmation = false

    private var currentItem: RecallItem? {
        queue.first
    }

    private var totalCount: Int {
        items.count
    }

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let currentItem {
                    List {
                        Section {
                            ProgressView(value: progress)
                                .accessibilityLabel("Session progress")
                        }

                        Section("Prompt") {
                            Text(currentItem.term)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .accessibilityAddTraits(.isHeader)
                        }

                        if let note = currentItem.note,
                           !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           revealedAnswer != nil {
                            Section("Context") {
                                Text(note)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section(revealedAnswer == nil ? "Recall" : "Answer") {
                            if let revealedAnswer {
                                Text(revealedAnswer)
                                    .font(.body)
                                    .textSelection(.enabled)
                            } else if isGeneratingAnswer {
                                HStack {
                                    ProgressView()
                                    Text("Generating answer...")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Recall it mentally, then reveal the answer.")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    ContentUnavailableView {
                        Label("Session Complete", systemImage: "checkmark.circle.fill")
                    } description: {
                        Text("You reviewed \(completedCount) \(completedCount == 1 ? "item" : "items").")
                    } actions: {
                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Done")
                    }
                }
            }
            .navigationTitle(currentItem == nil ? "Recall" : "\(min(completedCount + 1, max(totalCount, 1))) of \(totalCount)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if currentItem != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            if completedCount > 0 {
                                showingExitConfirmation = true
                            } else {
                                dismiss()
                            }
                        }
                        .accessibilityLabel("Close session")
                    }

                    ToolbarItemGroup(placement: .bottomBar) {
                        if let currentItem {
                            if revealedAnswer == nil {
                                Button {
                                    Task { await revealAnswer(for: currentItem) }
                                } label: {
                                    if isGeneratingAnswer {
                                        Label("Generating...", systemImage: "sparkles")
                                    } else {
                                        Label("Reveal", systemImage: "sparkles")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isGeneratingAnswer)
                                .accessibilityLabel(isGeneratingAnswer ? "Generating answer" : "Reveal answer")
                            } else {
                                ratingButton(title: Rating.forgot.rawValue, rating: .forgot, role: nil)
                                ratingButton(title: Rating.hard.rawValue, rating: .hard, role: nil)
                                ratingButton(title: Rating.easy.rawValue, rating: .easy, role: nil)
                            }
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isGeneratingAnswer)
        .alert("Couldn’t Generate Answer", isPresented: $showingGenerationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(generationErrorMessage)
        }
        .confirmationDialog("Leave session?", isPresented: $showingExitConfirmation, titleVisibility: .visible) {
            Button("Leave Session", role: .destructive) {
                dismiss()
            }
            Button("Continue", role: .cancel) { }
        } message: {
            Text("You’ll lose the rest of this recall session.")
        }
        .onAppear {
            if queue.isEmpty {
                queue = items.sorted { $0.nextDueDate < $1.nextDueDate }
            }
        }
    }

    private func ratingButton(title: String, rating: Rating, role: ButtonRole?) -> some View {
        Button(title, role: role) {
            rateCurrentItem(rating)
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(title)
    }

    private func revealAnswer(for item: RecallItem) async {
        if let cachedAnswer = item.cachedAIAnswer {
            revealedAnswer = cachedAnswer
            return
        }

        isGeneratingAnswer = true

        do {
            let answer = try await AIAnswerService.generateAnswer(
                term: item.term,
                context: item.note
            )
            item.cachedAIAnswerText = answer
            try modelContext.save()
            revealedAnswer = answer
        } catch {
            generationErrorMessage = error.localizedDescription
            showingGenerationError = true
        }

        isGeneratingAnswer = false
    }

    private func rateCurrentItem(_ rating: Rating) {
        guard let currentItem else { return }

        let review = Review(rating: rating)
        review.item = currentItem

        if currentItem.reviews == nil {
            currentItem.reviews = []
        }
        currentItem.reviews?.append(review)
        modelContext.insert(review)

        do {
            try modelContext.save()
        } catch {
            generationErrorMessage = "The review could not be saved."
            showingGenerationError = true
            return
        }

        completedCount += 1
        queue.removeFirst()
        revealedAnswer = nil
    }
}

#Preview("Recall Session") {
    RecallSessionScreen(items: RecallSessionPreviewService.sessionItems)
}

#Preview("Recall Session Complete") {
    RecallSessionScreen(items: [])
}
