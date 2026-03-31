import SwiftUI
import SwiftData

/// Shared in-memory data for SwiftUI previews and UI testing.
/// Use `PreviewData.container` as the model container in `#Preview` macros.
@MainActor
enum PreviewData {

    /// An in-memory ModelContainer pre-populated with representative sample items.
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: RecallItem.self, Review.self,
            configurations: config
        )
        insertSamples(into: container.mainContext)
        return container
    }()

    // MARK: - Sample insertion

    private static func insertSamples(into context: ModelContext) {
        // 1. New — never reviewed
        let newItem = RecallItem(term: "Amygdala", note: "Emotional processing region of the limbic system")
        context.insert(newItem)

        // 2. Due — reviewed with Forgot 2 days ago (1-day interval expired yesterday)
        let dueItem = RecallItem(term: "Hippocampus", note: "Converts short-term to long-term memory")
        context.insert(dueItem)
        let dueReview = Review(rating: .forgot)
        dueReview.reviewedAt = daysAgo(2)
        context.insert(dueReview)
        dueItem.reviews.append(dueReview)

        // 3. Upcoming (Hard) — reviewed 1 day ago, due in 2 days
        let hardItem = RecallItem(term: "Neuroplasticity", note: "The brain's ability to reorganise itself")
        context.insert(hardItem)
        let hardReview = Review(rating: .hard)
        hardReview.reviewedAt = daysAgo(1)
        context.insert(hardReview)
        hardItem.reviews.append(hardReview)

        // 4. Upcoming (Easy) — reviewed 2 days ago, due in 5 days
        let upcomingItem = RecallItem(term: "Synapse", note: "Gap between neurons where signals transfer")
        context.insert(upcomingItem)
        let upcomingReview = Review(rating: .easy)
        upcomingReview.reviewedAt = daysAgo(2)
        context.insert(upcomingReview)
        upcomingItem.reviews.append(upcomingReview)

        // 5. Mastered — 5 easy reviews over several weeks
        let masteredItem = RecallItem(term: "Action Potential", note: "Electrical impulse that travels along a neuron")
        context.insert(masteredItem)
        for i in 0..<5 {
            let r = Review(rating: .easy)
            r.reviewedAt = daysAgo(35 - i * 6)
            context.insert(r)
            masteredItem.reviews.append(r)
        }
    }

    private static func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date()) ?? Date()
    }
}
