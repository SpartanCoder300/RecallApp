import SwiftUI
import SwiftData

struct RecallSessionScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let items: [RecallItem]
    private let onRatePreview: ((RecallItem, Rating, String?) -> Void)?
    private let previewConfiguration: RecallSessionPreviewConfiguration?

    @State private var queue: [RecallItem] = []
    @State private var completedCount = 0
    @State private var results: [SessionResult] = []
    @State private var recalledText = ""
    @State private var revealedNote: String?
    @State private var hintText: String?
    @State private var queuedRetryItemIDs = Set<UUID>()
    @State private var deferredRetryItemIDs = Set<UUID>()
    @State private var retryCountsByItemID: [UUID: Int] = [:]
    @State private var saveErrorMessage = ""
    @State private var showingSaveError = false
    @State private var showingExitConfirmation = false
    @State private var lastUndoAction: SessionUndoAction?
    @FocusState private var recallFieldFocused: Bool
    @AppStorage(AppSettings.isProUserKey) private var isProUser = false
    @AppStorage(AppSettings.aiGradingEnabledKey) private var aiGradingEnabled = true
    @State private var gradingState: GradingState = .idle

    init(
        items: [RecallItem],
        onRatePreview: ((RecallItem, Rating, String?) -> Void)? = nil,
        previewConfiguration: RecallSessionPreviewConfiguration? = nil
    ) {
        self.items = items
        self.onRatePreview = onRatePreview
        self.previewConfiguration = previewConfiguration
        _queue = State(initialValue: previewConfiguration?.queue ?? [])
        _completedCount = State(initialValue: previewConfiguration?.completedCount ?? 0)
        _results = State(initialValue: previewConfiguration?.results ?? [])
        _recalledText = State(initialValue: previewConfiguration?.recalledText ?? "")
        _revealedNote = State(initialValue: previewConfiguration?.revealedNote)
        _hintText = State(initialValue: previewConfiguration?.hintText)
        _gradingState = State(initialValue: previewConfiguration?.gradingState ?? .idle)
    }

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

    private var hasAttemptedRecall: Bool {
        !recalledText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        hintText != nil ||
        revealedNote != nil
    }

    private var shouldUseAIGrading: Bool {
        isProUser && aiGradingEnabled
    }

    private var hasTypedRecall: Bool {
        !recalledText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isGradingInProgress: Bool {
        if case .loading = gradingState { return true }
        return false
    }

    private var currentGradingResult: GradingResult? {
        if case .result(let r) = gradingState { return r }
        return nil
    }

    private var shouldShowCheckButton: Bool {
        if case .loading = gradingState { return true }
        if case .idle = gradingState { return shouldUseAIGrading && hasTypedRecall }
        return false
    }

    private var canUndoLastAction: Bool {
        lastUndoAction != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DT.Color.background.ignoresSafeArea(.container)

                if let currentItem {
                    VStack(spacing: DT.Spacing.sm) {
                        progressBar

                        if showsRetryBanner(for: currentItem) {
                            retryBanner
                        }

                        RecallCardView(
                            item: currentItem,
                            recalledText: $recalledText,
                            hintText: hintText,
                            revealedNote: revealedNote,
                            canSkip: queue.count > 1,
                            recallFieldFocused: $recallFieldFocused,
                            onHint: revealHint,
                            onReveal: revealNote,
                            onSkip: skipCurrentItem,
                            showsRatings: hasAttemptedRecall,
                            gradingResult: currentGradingResult
                        )
                        .id(currentItem.id)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .padding(.horizontal, DT.Spacing.lg)
                    .padding(.top, DT.Spacing.md)
                    .padding(.bottom, DT.Spacing.lg)
                    .safeAreaInset(edge: .bottom) {
                        if case .result(let result) = gradingState {
                            AIGradingSuggestionView(
                                result: result,
                                canRetryLater: queue.count > 1 && !deferredRetryItemIDs.contains(currentItem.id),
                                onRate: rateCurrentItem,
                                onRetryNow: retryCurrentItemNow,
                                onRetryLater: deferCurrentItemForLater
                            )
                        } else if shouldShowCheckButton {
                            checkAnswerBar
                        } else if case .failed = gradingState {
                            failedGradingBar
                        } else if hasAttemptedRecall {
                            ratingBar
                        }
                    }
                } else {
                    sessionComplete
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if currentItem != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            handleClose()
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Close")
                    }

                    ToolbarItem(placement: .principal) {
                        Text("\(min(completedCount + 1, max(totalCount, 1))) of \(totalCount)")
                            .font(DT.Typography.subheadline)
                            .foregroundStyle(DT.Color.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                    }

                    ToolbarItemGroup(placement: .keyboard) {
                        if shouldShowCheckButton {
                            Button {
                                Task { await runAIGrading() }
                            } label: {
                                if isGradingInProgress {
                                    Text("Grading…")
                                } else {
                                    Label("Check Answer", systemImage: "sparkles")
                                }
                            }
                            .disabled(isGradingInProgress)
                            .accessibilityLabel(isGradingInProgress ? "Grading in progress" : "Check answer with AI")
                        }

                        Spacer()

                        Button("Done") {
                            recallFieldFocused = false
                        }
                        .accessibilityLabel("Dismiss keyboard")
                    }
                }

                if canUndoLastAction {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: undoLastAction) {
                            Image(systemName: "arrow.uturn.backward")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Undo last action")
                    }
                }
            }
        }
        .interactiveDismissDisabled(!queue.isEmpty)
        .alert("Unable to Save Review", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
        .confirmationDialog(
            "Leave Session?",
            isPresented: $showingExitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave Session", role: .destructive) {
                dismiss()
            }
            Button("Continue", role: .cancel) { }
        } message: {
            Text("You’ll lose your progress in this recall session.")
        }
        .onAppear {
            if queue.isEmpty, previewConfiguration == nil {
                queue = items.sorted { sessionPriority(of: $0) > sessionPriority(of: $1) }
            }
            if previewConfiguration?.focusRecallField == true || previewConfiguration == nil {
                DispatchQueue.main.async {
                    recallFieldFocused = true
                }
            }
        }
    }

    private var progressBar: some View {
        ProgressView(value: progress)
            .progressViewStyle(.linear)
            .tint(DT.Color.accent)
            .padding(.top, DT.Spacing.xs)
    }

    private var retryBanner: some View {
        Label(retryBannerText, systemImage: "arrow.clockwise")
            .font(DT.Typography.footnote)
            .foregroundStyle(DT.Color.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DT.Spacing.md)
            .background(DT.Color.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: DT.Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: DT.Radius.md)
                    .stroke(DT.Color.accent.opacity(0.22), lineWidth: 1)
            }
            .accessibilityLabel(retryBannerText)
    }

    private var sessionComplete: some View {
        SessionCompleteView(results: results) {
            dismiss()
        }
        .padding(DT.Spacing.lg)
    }

    private var ratingBar: some View {
        HStack(spacing: DT.Spacing.sm) {
            Button("Forgot") { rateCurrentItem(.forgot) }
                .buttonStyle(.borderedProminent)
                .tint(DT.Color.destructive)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Rate forgot")

            Button("Hard") { rateCurrentItem(.hard) }
                .buttonStyle(.borderedProminent)
                .tint(DT.Color.caution)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Rate hard")

            Button("Easy") { rateCurrentItem(.easy) }
                .buttonStyle(.borderedProminent)
                .tint(DT.Color.accent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Rate easy")
        }
        .padding(.horizontal, DT.Spacing.lg)
        .padding(.top, DT.Spacing.sm)
        .padding(.bottom, DT.Spacing.sm)
        .background(DT.Color.background)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var checkAnswerBar: some View {
        Button {
            Task { await runAIGrading() }
        } label: {
            Group {
                if isGradingInProgress {
                    HStack(spacing: DT.Spacing.sm) {
                        ProgressView().tint(.white)
                        Text("Grading…")
                    }
                } else {
                    Label("Check Answer", systemImage: "sparkles")
                }
            }
            .frame(maxWidth: .infinity)
            .fontWeight(.semibold)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isGradingInProgress)
        .padding(.horizontal, DT.Spacing.lg)
        .padding(.top, DT.Spacing.sm)
        .padding(.bottom, DT.Spacing.sm)
        .background(DT.Color.background)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityLabel(isGradingInProgress ? "Grading in progress" : "Check answer with AI")
    }

    private var failedGradingBar: some View {
        VStack(spacing: 0) {
            Text("AI grading unavailable — rate yourself")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
                .padding(.top, DT.Spacing.sm)
                .padding(.horizontal, DT.Spacing.lg)
                .frame(maxWidth: .infinity)
                .background(DT.Color.background)
                .accessibilityLabel("AI grading unavailable, please rate yourself manually")
            ratingBar
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// Returns an ordering priority for session queue sequencing.
    /// Higher values sort earlier. Forgot > New > Hard > Easy (overdue).
    private func sessionPriority(of item: RecallItem) -> Int {
        switch item.reviews?.max(by: { $0.reviewedAt < $1.reviewedAt })?.rating {
        case nil:     return 3  // New card — introduce early while attention is fresh
        case .forgot: return 4  // Recently forgotten — highest urgency
        case .hard:   return 2
        case .easy:   return 1
        }
    }

    private func revealHint() {
        guard let note = currentItem?.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else {
            hintText = "No hint available."
            return
        }

        let words = note.split(separator: " ")
        hintText = words.prefix(4).joined(separator: " ")
    }

    private func revealNote() {
        let note = currentItem?.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        revealedNote = (note?.isEmpty == false) ? note : "No answer available."
    }

    private func skipCurrentItem() {
        guard let currentItem, queue.count > 1 else { return }

        lastUndoAction = .skip(
            item: currentItem,
            cardState: currentCardState
        )

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            queue.removeFirst()
            queue.append(currentItem)
            resetCardState()
        }
    }

    private func retryCurrentItemNow() {
        guard currentItem != nil else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            recalledText = ""
            revealedNote = nil
            hintText = nil
            gradingState = .idle
        }

        HapticManager.selection()
        DispatchQueue.main.async {
            recallFieldFocused = true
        }
    }

    private func deferCurrentItemForLater() {
        guard let currentItem, queue.count > 1, !deferredRetryItemIDs.contains(currentItem.id) else { return }

        lastUndoAction = .deferRetry(
            item: currentItem,
            cardState: currentCardState
        )

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            deferredRetryItemIDs.insert(currentItem.id)
            queue.removeFirst()
            queue.append(currentItem)
            resetCardState()
        }

        HapticManager.warning()
    }

    private func rateCurrentItem(_ rating: Rating) {
        guard let currentItem else { return }

        let trimmedRecall = recalledText.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousCardState = currentCardState
        let gradingResult = currentGradingResult
        let wasQueuedForRetry = queuedRetryItemIDs.contains(currentItem.id)
        let wasDeferredForRetry = deferredRetryItemIDs.contains(currentItem.id)
        let didScheduleRetry = shouldQueueRetry(for: currentItem, rating: rating, gradingResult: gradingResult)
        let sessionResult = SessionResult(item: currentItem, rating: rating)
        let review = Review(
            rating: rating,
            recalledText: trimmedRecall.isEmpty ? nil : trimmedRecall
        )
        review.item = currentItem
        if let gradingResult {
            review.gradingReasoning = gradingResult.reasoning
            review.wasAIGraded = true
            review.aiSuggestedRating = gradingResult.suggestedRating.rawValue
            review.aiPrimaryFeedbackCategory = gradingResult.primaryFeedbackCategory
            review.aiSecondaryFeedbackCategory = gradingResult.secondaryFeedbackCategory
            review.aiCoreIdeaCorrect = gradingResult.coreIdeaCorrect
            review.aiMissingConcepts = gradingResult.missingConcepts
            review.aiIncorrectClaims = gradingResult.incorrectClaims
            review.aiConfidence = gradingResult.confidence
            review.aiShouldResurfaceSoon = gradingResult.shouldResurfaceSoon
        }

        if let onRatePreview {
            onRatePreview(currentItem, rating, trimmedRecall.isEmpty ? nil : trimmedRecall)
            HapticManager.success()
            lastUndoAction = .rate(
                item: currentItem,
                result: sessionResult,
                review: nil,
                cardState: previousCardState,
                didScheduleRetry: didScheduleRetry,
                wasQueuedForRetry: wasQueuedForRetry,
                wasDeferredForRetry: wasDeferredForRetry
            )

            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                applyRetryDecision(for: currentItem, shouldScheduleRetry: didScheduleRetry, wasQueuedForRetry: wasQueuedForRetry)
                deferredRetryItemIDs.remove(currentItem.id)
                results.append(sessionResult)
                queue.removeFirst()
                completedCount += 1
                resetCardState()
            }
            return
        }

        do {
            try modelContext.transaction {
                modelContext.insert(review)
                if currentItem.reviews == nil {
                    currentItem.reviews = [review]
                } else {
                    currentItem.reviews?.append(review)
                }
            }
        } catch {
            saveErrorMessage = "Please try again."
            showingSaveError = true
            HapticManager.error()
            return
        }

        HapticManager.success()
        lastUndoAction = .rate(
            item: currentItem,
            result: sessionResult,
            review: review,
            cardState: previousCardState,
            didScheduleRetry: didScheduleRetry,
            wasQueuedForRetry: wasQueuedForRetry,
            wasDeferredForRetry: wasDeferredForRetry
        )

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            applyRetryDecision(for: currentItem, shouldScheduleRetry: didScheduleRetry, wasQueuedForRetry: wasQueuedForRetry)
            deferredRetryItemIDs.remove(currentItem.id)
            results.append(sessionResult)
            queue.removeFirst()
            completedCount += 1
            resetCardState()
        }
    }

    private var currentCardState: RecallCardState {
        RecallCardState(
            recalledText: recalledText,
            revealedNote: revealedNote,
            hintText: hintText,
            gradingState: gradingState
        )
    }

    private func undoLastAction() {
        guard let lastUndoAction else { return }

        switch lastUndoAction {
        case .skip(let item, let cardState):
            guard let lastItem = queue.popLast() else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                queue.insert(lastItem.id == item.id ? lastItem : item, at: 0)
                restoreCardState(cardState)
                self.lastUndoAction = nil
            }

        case .deferRetry(let item, let cardState):
            if let deferredIndex = queue.lastIndex(where: { $0.id == item.id }) {
                queue.remove(at: deferredIndex)
            }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                deferredRetryItemIDs.remove(item.id)
                queue.insert(item, at: 0)
                restoreCardState(cardState)
                self.lastUndoAction = nil
            }

        case .rate(let item, let result, let review, let cardState, let didScheduleRetry, let wasQueuedForRetry, let wasDeferredForRetry):
            if let review {
                if let index = item.reviews?.firstIndex(where: { $0 === review }) {
                    item.reviews?.remove(at: index)
                }
                modelContext.delete(review)
            }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                revertRetryDecision(
                    for: item,
                    didScheduleRetry: didScheduleRetry,
                    wasQueuedForRetry: wasQueuedForRetry
                )
                if wasDeferredForRetry {
                    deferredRetryItemIDs.insert(item.id)
                }
                if let lastResult = results.last, lastResult.id == result.id {
                    results.removeLast()
                }
                completedCount = max(0, completedCount - 1)
                queue.insert(item, at: 0)
                restoreCardState(cardState)
                self.lastUndoAction = nil
            }
        }
    }

    private func resetCardState() {
        recalledText = ""
        revealedNote = nil
        hintText = nil
        gradingState = .idle
        DispatchQueue.main.async {
            recallFieldFocused = true
        }
    }

    private func restoreCardState(_ state: RecallCardState) {
        recalledText = state.recalledText
        revealedNote = state.revealedNote
        hintText = state.hintText
        gradingState = state.gradingState
        DispatchQueue.main.async {
            recallFieldFocused = state.gradingState.isIdle
        }
    }

    private func runAIGrading() async {
        guard let currentItem else { return }
        recallFieldFocused = false
        withAnimation { gradingState = .loading }

        do {
            let result = try await AnswerGradingService.grade(
                recalledText: recalledText,
                term: currentItem.term,
                note: currentItem.note,
                keyFacts: currentItem.keyFacts,
                acceptedSynonyms: currentItem.acceptedSynonyms,
                commonConfusions: currentItem.commonConfusions,
                collectionName: currentItem.collection?.name
            )
            withAnimation { gradingState = .result(result) }
            HapticManager.soft()
        } catch {
            // Model unavailable or unexpected response — fall back to manual rating bar
            withAnimation { gradingState = .failed }
        }
    }

    private func handleClose() {
        if !queue.isEmpty {
            showingExitConfirmation = true
        } else {
            dismiss()
        }
    }

    private func shouldQueueRetry(
        for item: RecallItem,
        rating: Rating,
        gradingResult: GradingResult?
    ) -> Bool {
        guard retryCountsByItemID[item.id, default: 0] == 0 else { return false }

        switch rating {
        case .forgot:
            return true
        case .hard:
            return gradingResult?.shouldResurfaceSoon ?? true
        case .easy:
            return false
        }
    }

    private func applyRetryDecision(
        for item: RecallItem,
        shouldScheduleRetry: Bool,
        wasQueuedForRetry: Bool
    ) {
        if shouldScheduleRetry {
            retryCountsByItemID[item.id, default: 0] += 1
            queuedRetryItemIDs.insert(item.id)
            queue.append(item)
            HapticManager.warning()
        } else if wasQueuedForRetry {
            queuedRetryItemIDs.remove(item.id)
        }
    }

    private func revertRetryDecision(
        for item: RecallItem,
        didScheduleRetry: Bool,
        wasQueuedForRetry: Bool
    ) {
        if didScheduleRetry {
            if let retryIndex = queue.lastIndex(where: { $0.id == item.id }) {
                queue.remove(at: retryIndex)
            }

            let remaining = max(0, retryCountsByItemID[item.id, default: 0] - 1)
            if remaining == 0 {
                retryCountsByItemID.removeValue(forKey: item.id)
                queuedRetryItemIDs.remove(item.id)
            } else {
                retryCountsByItemID[item.id] = remaining
                queuedRetryItemIDs.insert(item.id)
            }
        } else if wasQueuedForRetry {
            queuedRetryItemIDs.insert(item.id)
        }
    }

    private func showsRetryBanner(for item: RecallItem) -> Bool {
        deferredRetryItemIDs.contains(item.id) || queuedRetryItemIDs.contains(item.id)
    }

    private var retryBannerText: String {
        if let currentItem, deferredRetryItemIDs.contains(currentItem.id) {
            return "Corrective follow-up: rewrite this one with the missing distinction in mind."
        }
        return "Quick retry: tighten the missing detail before this leaves today’s session."
    }
}

enum GradingState {
    case idle
    case loading
    case result(GradingResult)
    case failed

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
}

private struct RecallCardState {
    let recalledText: String
    let revealedNote: String?
    let hintText: String?
    let gradingState: GradingState
}

private enum SessionUndoAction {
    case skip(item: RecallItem, cardState: RecallCardState)
    case deferRetry(item: RecallItem, cardState: RecallCardState)
    case rate(
        item: RecallItem,
        result: SessionResult,
        review: Review?,
        cardState: RecallCardState,
        didScheduleRetry: Bool,
        wasQueuedForRetry: Bool,
        wasDeferredForRetry: Bool
    )
}

struct SessionResult: Identifiable {
    let item: RecallItem
    let rating: Rating

    var id: UUID { item.id }
}

private struct RecallCardView: View {
    let item: RecallItem
    @Binding var recalledText: String
    let hintText: String?
    let revealedNote: String?
    let canSkip: Bool
    @FocusState.Binding var recallFieldFocused: Bool
    let onHint: () -> Void
    let onReveal: () -> Void
    let onSkip: () -> Void
    let showsRatings: Bool
    let gradingResult: GradingResult?

    var body: some View {
        ScrollView {
            VStack(spacing: DT.Spacing.sm) {
                Text(item.term)
                    .font(DT.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(DT.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, DT.Spacing.lg)

                if let gradingResult {
                    yourAnswerCard(text: recalledText)
                        .transition(.opacity)
                        .padding(.bottom, DT.Spacing.xs)
                    AIReasoningCard(result: gradingResult, commonConfusions: item.commonConfusions)
                        .transition(.opacity)

                    if let revealedNote {
                        disclosureCard(title: "Answer", text: revealedNote)
                            .transition(.opacity)
                    } else if hasStoredAnswer {
                        Button("Show Answer", action: onReveal)
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .accessibilityLabel("Show answer")
                            .transition(.opacity)
                    }
                } else {
                    RecallComposer(
                        text: $recalledText,
                        isFocused: $recallFieldFocused
                    )
                    .accessibilityLabel("Recall response")
                    .transition(.opacity)

                    if let hintText {
                        disclosureCard(title: "Hint", text: hintText)
                    }

                    if let revealedNote {
                        disclosureCard(title: "Answer", text: revealedNote)
                    }

                    HStack(spacing: DT.Spacing.sm) {
                        Button("Hint", action: onHint)
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .accessibilityLabel("Show hint")

                        Button("Answer", action: onReveal)
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .accessibilityLabel("Show answer")

                        Button("Skip", action: onSkip)
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(!canSkip)
                            .accessibilityLabel("Skip card")
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
                }

                Color.clear.frame(height: showsRatings ? 88 : 0)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var hasStoredAnswer: Bool {
        guard let note = item.note?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !note.isEmpty
    }

    private func yourAnswerCard(text: String) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: DT.Spacing.xs) {
            Text("Your Answer")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
            Text(trimmed.isEmpty ? "No answer entered" : trimmed)
                .font(DT.Typography.body)
                .foregroundStyle(trimmed.isEmpty ? DT.Color.textTertiary : DT.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DT.Spacing.md)
        .background(DT.Color.surfaceElevated, in: RoundedRectangle(cornerRadius: DT.Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your answer: \(trimmed.isEmpty ? "none" : trimmed)")
    }

    private func disclosureCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: DT.Spacing.xs) {
            Text(title)
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)

            Text(text)
                .font(DT.Typography.body)
                .foregroundStyle(DT.Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DT.Spacing.md)
        .background(DT.Color.surface, in: RoundedRectangle(cornerRadius: DT.Radius.lg))
    }
}

private struct RecallComposer: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: DT.Radius.lg)
                .fill(DT.Color.surface)

            TextEditor(text: $text)
                .font(DT.Typography.body)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .padding(.horizontal, DT.Spacing.sm)
                .padding(.vertical, DT.Spacing.sm)

            if text.isEmpty {
                Text("What do you remember about this?")
                    .font(DT.Typography.body)
                    .foregroundStyle(DT.Color.textTertiary)
                    .padding(.horizontal, DT.Spacing.md)
                    .padding(.vertical, DT.Spacing.md)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 160)
    }
}

struct SessionCompleteView: View {
    let results: [SessionResult]
    let onDone: () -> Void

    @State private var iconVisible = false
    @State private var celebrationVisible = false

    private var easyCount: Int {
        results.filter { $0.rating == .easy }.count
    }

    private var hardCount: Int {
        results.filter { $0.rating == .hard }.count
    }

    private var forgotCount: Int {
        results.filter { $0.rating == .forgot }.count
    }

    private var headline: String {
        if !results.isEmpty, easyCount == results.count {
            return "Perfect session!"
        }
        return "Session done"
    }

    private var isPerfectSession: Bool {
        !results.isEmpty && easyCount == results.count
    }

    var body: some View {
        VStack(spacing: DT.Spacing.lg) {
            Spacer(minLength: DT.Spacing.xl)

            ZStack {
                if isPerfectSession {
                    CelebrationBurstView(isVisible: celebrationVisible)
                }

                Image(systemName: "checkmark.circle.fill")
                    .font(DT.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(DT.Color.accent)
                    .scaleEffect(iconVisible ? 1 : 0.7)
                    .opacity(iconVisible ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.65), value: iconVisible)
            }
            .frame(height: 88)

            VStack(spacing: DT.Spacing.sm) {
                Text(headline)
                    .font(DT.Typography.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(DT.Color.textPrimary)

                HStack(spacing: DT.Spacing.md) {
                    breakdownChip(title: "Easy", value: easyCount, color: DT.Color.accent)
                    breakdownChip(title: "Hard", value: hardCount, color: DT.Color.caution)
                    breakdownChip(title: "Forgot", value: forgotCount, color: DT.Color.destructive)
                }
            }
            .padding(.horizontal, DT.Spacing.sm)

            ScrollView {
                VStack(spacing: DT.Spacing.sm) {
                    ForEach(results) { result in
                        SessionResultRow(result: result)
                    }
                }
                .padding(.horizontal, DT.Spacing.sm)
            }
            .frame(maxHeight: 160)

            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: 220)
                .accessibilityLabel("Done")

            Spacer(minLength: DT.Spacing.lg)
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, DT.Spacing.lg)
        .padding(.top, DT.Spacing.xxl)
        .padding(.bottom, DT.Spacing.xl)
        .onAppear {
            iconVisible = true
            if isPerfectSession {
                celebrationVisible = true
            }
        }
    }

    private func breakdownChip(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: DT.Spacing.xs) {
            Text("\(value)")
                .font(DT.Typography.headline)
                .foregroundStyle(DT.Color.textPrimary)

            Text(title)
                .font(DT.Typography.caption)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DT.Spacing.sm)
        .background(DT.Color.surface, in: RoundedRectangle(cornerRadius: DT.Radius.md))
    }
}

private struct SessionResultRow: View {
    let result: SessionResult

    var body: some View {
        HStack(spacing: DT.Spacing.md) {
            Image(systemName: symbolName)
                .foregroundStyle(symbolColor)
                .frame(width: 20)

            Text(result.item.term)
                .font(DT.Typography.body)
                .foregroundStyle(DT.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(result.rating.rawValue)
                .font(DT.Typography.footnote)
                .foregroundStyle(DT.Color.textSecondary)
        }
        .padding(.horizontal, DT.Spacing.md)
        .padding(.vertical, DT.Spacing.sm)
        .background(DT.Color.surface, in: RoundedRectangle(cornerRadius: DT.Radius.md))
    }

    private var symbolName: String {
        switch result.rating {
        case .easy: return "checkmark"
        case .hard: return "tilde"
        case .forgot: return "xmark"
        }
    }

    private var symbolColor: Color {
        switch result.rating {
        case .easy: return DT.Color.accent
        case .hard: return DT.Color.caution
        case .forgot: return DT.Color.destructive
        }
    }
}

private struct CelebrationBurstView: View {
    let isVisible: Bool

    private let colors: [Color] = [
        DT.Color.accent,
        DT.Color.caution,
        DT.Color.destructive,
        DT.Color.success
    ]

    var body: some View {
        ZStack {
            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .offset(confettiOffset(for: index))
                    .scaleEffect(isVisible ? 1 : 0.2)
                    .opacity(isVisible ? 0 : 1)
                    // Custom: a short ease-out keeps the celebratory burst readable without lingering.
                    .animation(
                        .easeOut(duration: 0.7).delay(Double(index) * 0.03),
                        value: isVisible
                    )
            }
        }
    }

    private func confettiOffset(for index: Int) -> CGSize {
        let positions: [CGSize] = [
            CGSize(width: -50, height: -36),
            CGSize(width: -18, height: -58),
            CGSize(width: 20, height: -56),
            CGSize(width: 52, height: -32)
        ]
        return positions[index]
    }
}

struct AIReasoningCard: View {
    let result: GradingResult
    let commonConfusions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.md) {
            HStack(spacing: DT.Spacing.sm) {
                Label("AI Grading", systemImage: "sparkles")
                    .font(DT.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DT.Color.accent)

                Spacer(minLength: DT.Spacing.sm)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Suggested rating")
                        .font(DT.Typography.caption)
                        .foregroundStyle(DT.Color.textSecondary)

                    Text(result.suggestedRating.rawValue)
                        .font(DT.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(ratingTint)
                        .padding(.horizontal, DT.Spacing.sm)
                        .padding(.vertical, DT.Spacing.xs)
                        .background(ratingTint.opacity(0.14), in: Capsule())
                        .accessibilityHidden(true)
                }
            }

            Text(result.reasoning)
                .font(DT.Typography.callout)
                .foregroundStyle(DT.Color.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: DT.Spacing.sm) {
                HStack(spacing: DT.Spacing.sm) {
                    feedbackChip(result.primaryFeedbackCategory.title)

                    if let secondaryFeedbackCategory = result.secondaryFeedbackCategory {
                        feedbackChip(secondaryFeedbackCategory.title)
                    }
                }

                metadataRow(
                    title: feedbackHeadline.title,
                    value: feedbackHeadline.value
                )

                if let missingConcepts = result.missingConcepts {
                    metadataRow(title: "You omitted", value: missingConcepts)
                }

                if let incorrectClaims = result.incorrectClaims {
                    metadataRow(title: "You confused", value: incorrectClaims)
                }

                metadataRow(title: "Confidence", value: result.confidence.rawValue)

                if result.shouldResurfaceSoon {
                    metadataRow(title: "Follow-up", value: "A Hard or Forgot rating brings this back once more today")
                }

                if let distinction = distinctionText {
                    metadataRow(title: "Missed distinction", value: distinction)
                }

                if let comparison = comparisonText {
                    metadataRow(title: "Watch this confusion", value: comparison)
                }
            }
        }
        .padding(DT.Spacing.md)
        .background(DT.Color.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: DT.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DT.Radius.lg)
                .stroke(DT.Color.accent.opacity(0.3), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func metadataRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)

            Text(value)
                .font(DT.Typography.subheadline)
                .foregroundStyle(DT.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func feedbackChip(_ title: String) -> some View {
        Text(title)
            .font(DT.Typography.caption)
            .foregroundStyle(DT.Color.accent)
            .padding(.horizontal, DT.Spacing.sm)
            .padding(.vertical, DT.Spacing.xs)
            .background(DT.Color.accent.opacity(0.12), in: Capsule())
    }

    private var accessibilitySummary: String {
        var parts = [
            "AI grading suggested \(result.suggestedRating.rawValue).",
            result.reasoning,
            "\(result.primaryFeedbackCategory.title).",
            result.coreIdeaCorrect ? "Core idea captured." : "Core idea missing.",
            "Confidence \(result.confidence.rawValue)."
        ]

        if let secondaryFeedbackCategory = result.secondaryFeedbackCategory {
            parts.append("\(secondaryFeedbackCategory.title).")
        }

        if let missingConcepts = result.missingConcepts {
            parts.append("Missing \(missingConcepts).")
        }

        if let incorrectClaims = result.incorrectClaims {
            parts.append("Incorrect \(incorrectClaims).")
        }

        if result.shouldResurfaceSoon {
            parts.append("A hard or forgot rating brings this back once more today.")
        }

        if let distinction = distinctionText {
            parts.append("Missed distinction \(distinction).")
        }

        if let comparison = comparisonText {
            parts.append("Watch this confusion \(comparison).")
        }

        return parts.joined(separator: " ")
    }

    private var distinctionText: String? {
        result.incorrectClaims ?? result.missingConcepts
    }

    private var comparisonText: String? {
        guard !commonConfusions.isEmpty, result.incorrectClaims != nil || result.missingConcepts != nil else {
            return nil
        }
        return commonConfusions.prefix(2).joined(separator: " • ")
    }

    private var ratingTint: Color {
        switch result.suggestedRating {
        case .forgot:
            DT.Color.destructive
        case .hard:
            DT.Color.caution
        case .easy:
            DT.Color.accent
        }
    }

    private var feedbackHeadline: (title: String, value: String) {
        switch result.primaryFeedbackCategory {
        case .mainIdeaCaptured:
            return ("You got the main idea", result.reasoning)
        case .causalMechanismMissing:
            return ("You missed the causal mechanism", result.missingConcepts ?? result.reasoning)
        case .confusedConcepts:
            return ("You confused this with something else", result.incorrectClaims ?? result.reasoning)
        case .exceptionOmitted:
            return ("You omitted the exception", result.missingConcepts ?? result.reasoning)
        case .importantQualifierMissing:
            return ("You missed the qualifier", result.missingConcepts ?? result.reasoning)
        case .criticalDetailMissing:
            return ("You missed a critical detail", result.missingConcepts ?? result.reasoning)
        }
    }
}

struct AIGradingSuggestionView: View {
    let result: GradingResult
    let canRetryLater: Bool
    let onRate: (Rating) -> Void
    let onRetryNow: () -> Void
    let onRetryLater: () -> Void

    var body: some View {
        VStack(spacing: DT.Spacing.sm) {
            HStack(alignment: .bottom, spacing: DT.Spacing.sm) {
                ratingButton(.forgot, label: "Forgot", tint: DT.Color.destructive)
                ratingButton(.hard,   label: "Hard",   tint: DT.Color.caution)
                ratingButton(.easy,   label: "Easy",   tint: DT.Color.accent)
            }

            correctiveActions
        }
        .padding(.horizontal, DT.Spacing.lg)
        .padding(.top, DT.Spacing.sm)
        .padding(.bottom, DT.Spacing.sm)
        .background(DT.Color.background)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var correctiveActions: some View {
        HStack(spacing: DT.Spacing.sm) {
            Button("Retry Now", action: onRetryNow)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Retry now")

            Button("Retry Later", action: onRetryLater)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .frame(maxWidth: .infinity)
                .disabled(!canRetryLater)
                .accessibilityLabel("Retry later in this session")
        }
    }

    @ViewBuilder
    private func ratingButton(_ rating: Rating, label: String, tint: Color) -> some View {
        let isSuggested = rating == result.suggestedRating
        if isSuggested {
            Button { onRate(rating) } label: {
                Label(label, systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: DT.Radius.md))
            .tint(tint.opacity(0.82))
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: DT.Radius.md)
                    .stroke(tint.opacity(0.42), lineWidth: 1.5)
            }
            .accessibilityLabel("\(label), AI suggested")
        } else {
            Button(label) { onRate(rating) }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: DT.Radius.md))
                .tint(tint.opacity(0.82))
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Override to \(label.lowercased())")
        }
    }
}

#Preview("Recall Session Light") {
    RecallSessionScreen(
        items: RecallSessionPreviewService.sessionItems,
        onRatePreview: { _, _, _ in },
        previewConfiguration: RecallSessionPreviewService.liveSessionConfiguration
    )
    .preferredColorScheme(.light)
}

#Preview("Recall Session Dark") {
    RecallSessionScreen(
        items: RecallSessionPreviewService.sessionItems,
        onRatePreview: { _, _, _ in },
        previewConfiguration: RecallSessionPreviewService.liveSessionConfiguration
    )
    .preferredColorScheme(.dark)
}

#Preview("AI Response Light") {
    RecallSessionScreen(
        items: RecallSessionPreviewService.sessionItems,
        onRatePreview: { _, _, _ in },
        previewConfiguration: RecallSessionPreviewService.aiResponseConfiguration
    )
    .preferredColorScheme(.light)
}

#Preview("AI Response Dark") {
    RecallSessionScreen(
        items: RecallSessionPreviewService.sessionItems,
        onRatePreview: { _, _, _ in },
        previewConfiguration: RecallSessionPreviewService.aiResponseConfiguration
    )
    .preferredColorScheme(.dark)
}

#Preview("Session Complete Light") {
    RecallSessionScreen(
        items: RecallSessionPreviewService.sessionItems,
        onRatePreview: { _, _, _ in },
        previewConfiguration: RecallSessionPreviewService.sessionCompleteConfiguration
    )
    .preferredColorScheme(.light)
}

#Preview("Session Complete Dark") {
    RecallSessionScreen(
        items: RecallSessionPreviewService.sessionItems,
        onRatePreview: { _, _, _ in },
        previewConfiguration: RecallSessionPreviewService.sessionCompleteConfiguration
    )
    .preferredColorScheme(.dark)
}
