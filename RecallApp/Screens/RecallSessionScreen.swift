import SwiftUI
import SwiftData

struct RecallSessionScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let items: [RecallItem]
    private let onRatePreview: ((RecallItem, Rating, String?) -> Void)?

    @State private var queue: [RecallItem] = []
    @State private var completedCount = 0
    @State private var results: [SessionResult] = []
    @State private var recalledText = ""
    @State private var revealedNote: String?
    @State private var hintText: String?
    @State private var saveErrorMessage = ""
    @State private var showingSaveError = false
    @State private var showingExitConfirmation = false
    @FocusState private var recallFieldFocused: Bool

    init(
        items: [RecallItem],
        onRatePreview: ((RecallItem, Rating, String?) -> Void)? = nil
    ) {
        self.items = items
        self.onRatePreview = onRatePreview
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

    var body: some View {
        NavigationStack {
            ZStack {
                DT.Color.background.ignoresSafeArea()

                if let currentItem {
                    VStack(spacing: DT.Spacing.sm) {
                        progressBar

                        RecallCardView(
                            item: currentItem,
                            recalledText: $recalledText,
                            hintText: hintText,
                            revealedNote: revealedNote,
                            hasAttemptedRecall: hasAttemptedRecall,
                            canSkip: queue.count > 1,
                            recallFieldFocused: $recallFieldFocused,
                            onHint: revealHint,
                            onReveal: revealNote,
                            onSkip: skipCurrentItem,
                            onRate: rateCurrentItem(_:)
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
            if queue.isEmpty {
                queue = items
            }
            DispatchQueue.main.async {
                recallFieldFocused = true
            }
        }
    }

    private var progressBar: some View {
        ProgressView(value: progress)
            .progressViewStyle(.linear)
            .tint(DT.Color.accent)
            .padding(.top, DT.Spacing.xs)
    }

    private var sessionComplete: some View {
        SessionCompleteView(results: results) {
            dismiss()
        }
        .padding(DT.Spacing.lg)
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
        revealedNote = (note?.isEmpty == false) ? note : "No note available."
    }

    private func skipCurrentItem() {
        guard let currentItem, queue.count > 1 else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            queue.removeFirst()
            queue.append(currentItem)
            resetCardState()
        }
    }

    private func rateCurrentItem(_ rating: Rating) {
        guard let currentItem else { return }

        let trimmedRecall = recalledText.trimmingCharacters(in: .whitespacesAndNewlines)
        let review = Review(
            rating: rating,
            recalledText: trimmedRecall.isEmpty ? nil : trimmedRecall
        )
        review.item = currentItem

        if let onRatePreview {
            onRatePreview(currentItem, rating, trimmedRecall.isEmpty ? nil : trimmedRecall)
            HapticManager.success()

            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                results.append(SessionResult(item: currentItem, rating: rating))
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

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            results.append(SessionResult(item: currentItem, rating: rating))
            queue.removeFirst()
            completedCount += 1
            resetCardState()
        }
    }

    private func resetCardState() {
        recalledText = ""
        revealedNote = nil
        hintText = nil
        DispatchQueue.main.async {
            recallFieldFocused = true
        }
    }

    private func handleClose() {
        if !queue.isEmpty {
            showingExitConfirmation = true
        } else {
            dismiss()
        }
    }
}

private struct SessionResult: Identifiable {
    let item: RecallItem
    let rating: Rating

    var id: UUID { item.id }
}

private struct RecallCardView: View {
    let item: RecallItem
    @Binding var recalledText: String
    let hintText: String?
    let revealedNote: String?
    let hasAttemptedRecall: Bool
    let canSkip: Bool
    @FocusState.Binding var recallFieldFocused: Bool
    let onHint: () -> Void
    let onReveal: () -> Void
    let onSkip: () -> Void
    let onRate: (Rating) -> Void

    var body: some View {
        VStack(spacing: DT.Spacing.sm) {
            Text(item.term)
                .font(DT.Typography.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(DT.Color.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, DT.Spacing.lg)

            RecallComposer(
                text: $recalledText,
                isFocused: $recallFieldFocused
            )
                .accessibilityLabel("Recall response")

            if let hintText {
                disclosureCard(title: "Hint", text: hintText)
            }

            if let revealedNote {
                disclosureCard(title: "Revealed note", text: revealedNote)
            }

            HStack(spacing: DT.Spacing.sm) {
                Button("Hint", action: onHint)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .accessibilityLabel("Show hint")

                Button("Reveal", action: onReveal)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .accessibilityLabel("Reveal note")

                Button("Skip", action: onSkip)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(!canSkip)
                    .accessibilityLabel("Skip card")
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: DT.Spacing.xl)

            if hasAttemptedRecall {
                HStack(spacing: DT.Spacing.sm) {
                    Button("Forgot") { onRate(.forgot) }
                        .buttonStyle(.borderedProminent)
                        .tint(DT.Color.destructive)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Rate forgot")

                    Button("Hard") { onRate(.hard) }
                        .buttonStyle(.borderedProminent)
                        .tint(DT.Color.caution)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Rate hard")

                    Button("Easy") { onRate(.easy) }
                        .buttonStyle(.borderedProminent)
                        .tint(DT.Color.accent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Rate easy")
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
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

private struct SessionCompleteView: View {
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
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
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

#Preview("Recall Session") {
    RecallSessionScreen(items: [
        PreviewService.itemWithNote,
        PreviewService.itemWithoutNote
    ], onRatePreview: { _, _, _ in })
}

#Preview("Session Complete") {
    SessionCompleteView(
        results: [
            SessionResult(item: PreviewService.itemWithNote, rating: .easy),
            SessionResult(item: PreviewService.itemWithoutNote, rating: .hard)
        ],
        onDone: { }
    )
}
