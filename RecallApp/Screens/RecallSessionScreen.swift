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
    @State private var dragOffset: CGSize = .zero
    @State private var isDismissing = false

    private let swipeThreshold: CGFloat = 90

    private var currentItem: RecallItem? { queue.first }
    private var totalCount: Int { items.count }
    private var progress: Double {
        guard totalCount > 0 else { return 1 }
        return Double(completedCount) / Double(totalCount)
    }

    // The rating the current drag position would commit, or nil if not past threshold.
    private var dragRating: Rating? {
        guard revealedAnswer != nil else { return nil }
        if dragOffset.width > swipeThreshold { return .nailed }
        if dragOffset.width < -swipeThreshold { return .missed }
        if dragOffset.height > swipeThreshold { return .partial }
        return nil
    }

    // 0–1 opacity that ramps up as the drag approaches / passes the threshold.
    private var dragProgress: Double {
        guard revealedAnswer != nil else { return 0 }
        let x = abs(dragOffset.width)
        let y = max(0, dragOffset.height)
        return min(Double(max(x, y)) / Double(swipeThreshold), 1.0)
    }

    private var cardRotation: Double {
        Double(dragOffset.width) / 22.0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DT.Color.background.ignoresSafeArea()

                if let currentItem {
                    sessionContent(for: currentItem)
                } else {
                    completionView
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
                }
            }
        }
        .interactiveDismissDisabled(isGeneratingAnswer)
        .alert("Couldn't Generate Answer", isPresented: $showingGenerationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(generationErrorMessage)
        }
        .confirmationDialog("Leave session?", isPresented: $showingExitConfirmation, titleVisibility: .visible) {
            Button("Leave Session", role: .destructive) { dismiss() }
            Button("Continue", role: .cancel) { }
        } message: {
            Text("You'll lose the rest of this recall session.")
        }
        .onAppear {
            if queue.isEmpty {
                queue = items.sorted { $0.nextDueDate < $1.nextDueDate }
            }
        }
    }

    // MARK: - Session layout

    private func sessionContent(for item: RecallItem) -> some View {
        VStack(spacing: 0) {
            ProgressView(value: progress)
                .padding(.horizontal, DT.Spacing.lg)
                .padding(.top, DT.Spacing.sm)
                .accessibilityLabel("Session progress, \(completedCount) of \(totalCount) complete")

            Spacer(minLength: DT.Spacing.lg)

            card(for: item)
                .padding(.horizontal, DT.Spacing.lg)

            Spacer(minLength: DT.Spacing.lg)

            hintBar
                .padding(.horizontal, DT.Spacing.xl)
                .padding(.bottom, DT.Spacing.lg)
        }
    }

    // MARK: - Card

    private func card(for item: RecallItem) -> some View {
        ZStack(alignment: .topLeading) {
            // Base surface
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.surface)

            // Coloured rating wash
            if let rating = dragRating {
                RoundedRectangle(cornerRadius: DT.Radius.card)
                    .fill(color(for: rating).opacity(dragProgress * 0.45))
            }

            // Card text content
            cardBody(for: item)

            // Stamp label
            if let rating = dragRating {
                stampLabel(for: rating)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .offset(dragOffset)
        .rotationEffect(.degrees(cardRotation), anchor: .bottom)
        .accessibilityAction(named: "Reveal answer") {
            guard revealedAnswer == nil, !isGeneratingAnswer else { return }
            Task { await revealAnswer(for: item) }
        }
        .accessibilityAction(named: "Nailed it") {
            guard revealedAnswer != nil else { return }
            commitRating(.nailed)
        }
        .accessibilityAction(named: "Partial recall") {
            guard revealedAnswer != nil else { return }
            commitRating(.partial)
        }
        .accessibilityAction(named: "Missed it") {
            guard revealedAnswer != nil else { return }
            commitRating(.missed)
        }
        .onTapGesture {
            guard revealedAnswer == nil, !isGeneratingAnswer, !isDismissing else { return }
            Task { await revealAnswer(for: item) }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard revealedAnswer != nil, !isDismissing else { return }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    guard revealedAnswer != nil, !isDismissing else { return }
                    handleSwipeEnd(translation: value.translation)
                }
        )
    }

    private func cardBody(for item: RecallItem) -> some View {
        VStack(alignment: .leading, spacing: DT.Spacing.lg) {
            Text(item.term)
                .font(DT.Typography.title3)
                .fontWeight(.semibold)
                .foregroundStyle(DT.Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let answer = revealedAnswer {
                Divider()

                if let note = item.note,
                   !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(note)
                        .font(DT.Typography.footnote)
                        .foregroundStyle(DT.Color.textSecondary)
                }

                Text(answer)
                    .font(DT.Typography.body)
                    .foregroundStyle(DT.Color.textPrimary)
                    .textSelection(.enabled)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if isGeneratingAnswer {
                Divider()
                HStack(spacing: DT.Spacing.sm) {
                    ProgressView()
                    Text("Generating answer…")
                        .font(DT.Typography.body)
                        .foregroundStyle(DT.Color.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(DT.Spacing.lg)
    }

    private func stampLabel(for rating: Rating) -> some View {
        let isDown = dragOffset.height > 0 && abs(dragOffset.height) > abs(dragOffset.width)
        let rotation: Double = isDown ? 0 : (dragOffset.width > 0 ? -12 : 12)

        return Text(name(for: rating).uppercased())
            .font(DT.Typography.title2)
            .fontWeight(.heavy)
            .foregroundStyle(color(for: rating))
            .padding(.horizontal, DT.Spacing.sm)
            .padding(.vertical, DT.Spacing.xs)
            .overlay(
                RoundedRectangle(cornerRadius: DT.Radius.sm)
                    .stroke(color(for: rating), lineWidth: 3)
            )
            .rotationEffect(.degrees(rotation))
            .opacity(dragProgress)
            .padding(DT.Spacing.md)
    }

    // MARK: - Hint bar

    @ViewBuilder
    private var hintBar: some View {
        if revealedAnswer != nil {
            HStack {
                Label("Missed", systemImage: "arrow.left")
                    .foregroundStyle(DT.Color.destructive)
                Spacer()
                Label("Partial", systemImage: "arrow.down")
                    .foregroundStyle(DT.Color.caution)
                Spacer()
                Label("Nailed", systemImage: "arrow.right")
                    .foregroundStyle(DT.Color.success)
            }
            .font(DT.Typography.caption)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Swipe left for Missed, down for Partial, right for Nailed")
        } else {
            Text(isGeneratingAnswer ? "Generating answer…" : "Tap card to reveal")
                .font(DT.Typography.footnote)
                .foregroundStyle(DT.Color.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Completion

    private var completionView: some View {
        ContentUnavailableView {
            Label("Session Complete", systemImage: "checkmark.circle.fill")
        } description: {
            Text("You reviewed \(completedCount) \(completedCount == 1 ? "item" : "items").")
        } actions: {
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Done")
        }
    }

    // MARK: - Gesture handling

    private func handleSwipeEnd(translation: CGSize) {
        let rating: Rating?
        if translation.width > swipeThreshold { rating = .nailed }
        else if translation.width < -swipeThreshold { rating = .missed }
        else if translation.height > swipeThreshold { rating = .partial }
        else { rating = nil }

        guard let rating else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                dragOffset = .zero
            }
            return
        }

        commitRating(rating)
    }

    private func commitRating(_ rating: Rating) {
        guard !isDismissing else { return }
        isDismissing = true

        withAnimation(.easeIn(duration: 0.2)) {
            dragOffset = exitOffset(for: rating)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dragOffset = .zero
            rateCurrentItem(rating)
            isDismissing = false
        }
    }

    private func exitOffset(for rating: Rating) -> CGSize {
        switch rating {
        case .nailed:  return CGSize(width: 600, height: 0)
        case .missed:  return CGSize(width: -600, height: 0)
        case .partial: return CGSize(width: 0, height: 600)
        }
    }

    // MARK: - Data

    private func revealAnswer(for item: RecallItem) async {
        if let existing = item.answer, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            HapticManager.light()
            withAnimation { revealedAnswer = existing }
            return
        }

        isGeneratingAnswer = true
        HapticManager.light()

        do {
            let generated = try await AIAnswerService.generateAnswer(term: item.term, context: item.note)
            item.answer = generated
            try modelContext.save()
            withAnimation { revealedAnswer = generated }
        } catch {
            generationErrorMessage = error.localizedDescription
            showingGenerationError = true
        }

        isGeneratingAnswer = false
    }

    private func rateCurrentItem(_ rating: Rating) {
        guard let currentItem else { return }

        switch rating {
        case .nailed:  HapticManager.success()
        case .partial: HapticManager.medium()
        case .missed:  HapticManager.warning()
        }

        let review = Review(rating: rating)
        review.item = currentItem
        if currentItem.reviews == nil { currentItem.reviews = [] }
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

    // MARK: - Helpers

    private func color(for rating: Rating) -> Color {
        switch rating {
        case .nailed:  return DT.Color.success
        case .partial: return DT.Color.caution
        case .missed:  return DT.Color.destructive
        }
    }

    private func name(for rating: Rating) -> String {
        switch rating {
        case .nailed:  return "Nailed"
        case .partial: return "Partial"
        case .missed:  return "Missed"
        }
    }
}

#Preview("Recall Session") {
    RecallSessionScreen(items: RecallSessionPreviewService.sessionItems)
}

#Preview("Recall Session Complete") {
    RecallSessionScreen(items: [])
}
