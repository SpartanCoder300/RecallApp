import SwiftUI
import SwiftData

/// Shared in-memory data for SwiftUI previews and UI testing.
/// Use `PreviewData.container` as the model container in `#Preview` macros.
@MainActor
enum PreviewData {

    /// An in-memory ModelContainer pre-populated with representative sample items and collections.
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: RecallItem.self, Review.self, RecallCollection.self,
            configurations: config
        )
        insertSamples(into: container.mainContext)
        return container
    }()

    // MARK: - Sample insertion

    private static func insertSamples(into context: ModelContext) {

        // MARK: Collections
        let interviewCollection = RecallCollection(name: "Interview Prep", color: .blue)
        context.insert(interviewCollection)

        let iotCollection = RecallCollection(name: "IoT Concepts", color: .teal)
        context.insert(iotCollection)

        let generalCollection = RecallCollection(name: "General", color: .purple)
        context.insert(generalCollection)

        // MARK: Items

        // 1. New — never reviewed (Interview Prep)
        let newItem = RecallItem(term: "System Design", note: "How to approach scalable architecture questions")
        context.insert(newItem)
        newItem.collection = interviewCollection

        // 2. Due — reviewed with Forgot 2 days ago (1-day interval expired yesterday) (IoT)
        let dueItem = RecallItem(term: "MQTT Protocol", note: "Lightweight pub/sub messaging for constrained devices")
        context.insert(dueItem)
        dueItem.collection = iotCollection
        let dueReview = Review(rating: .forgot)
        dueReview.reviewedAt = daysAgo(2)
        context.insert(dueReview)
        dueItem.reviews.append(dueReview)

        // 3. Upcoming (Hard) — reviewed 1 day ago, due in 2 days (Interview Prep)
        let hardItem = RecallItem(term: "CAP Theorem", note: "Consistency, Availability, Partition tolerance trade-off")
        context.insert(hardItem)
        hardItem.collection = interviewCollection
        let hardReview = Review(rating: .hard)
        hardReview.reviewedAt = daysAgo(1)
        context.insert(hardReview)
        hardItem.reviews.append(hardReview)

        // 4. Upcoming (Easy) — reviewed 2 days ago, due in 5 days (IoT)
        let upcomingItem = RecallItem(term: "Edge Computing", note: "Processing data near the source rather than in the cloud")
        context.insert(upcomingItem)
        upcomingItem.collection = iotCollection
        let upcomingReview = Review(rating: .easy)
        upcomingReview.reviewedAt = daysAgo(2)
        context.insert(upcomingReview)
        upcomingItem.reviews.append(upcomingReview)

        // 5. Mastered — 5 easy reviews over several weeks (no collection — free-floating)
        let masteredItem = RecallItem(term: "Action Potential", note: "Electrical impulse that travels along a neuron")
        context.insert(masteredItem)
        for i in 0..<5 {
            let r = Review(rating: .easy)
            r.reviewedAt = daysAgo(35 - i * 6)
            context.insert(r)
            masteredItem.reviews.append(r)
        }

        // 6. Due — no collection (free-floating item)
        let freeItem = RecallItem(term: "Neuroplasticity", note: "The brain's ability to reorganise itself")
        context.insert(freeItem)
        let freeReview = Review(rating: .forgot)
        freeReview.reviewedAt = daysAgo(3)
        context.insert(freeReview)
        freeItem.reviews.append(freeReview)
    }

    private static func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date()) ?? Date()
    }
}
