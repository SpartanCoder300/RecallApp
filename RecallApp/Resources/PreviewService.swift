import Foundation

enum PreviewService {
    static let libraryItems: [RecallItem] = sampleItems

    static let homeSnapshot: HomeScreenSnapshot = {
        let items = sampleItems
        let reviews = sampleReviews
        return HomeScreenSnapshot.makePreviewSnapshot(
            allItems: items,
            allReviews: reviews,
            now: Date()
        )
    }()

    static let emptyHomeSnapshot = HomeScreenSnapshot(
        greeting: HomeScreenSnapshot.greeting(for: Date()),
        streak: 0,
        dueCount: 0,
        todaysItems: [],
        previousDueItems: []
    )

    static let itemWithNote: RecallItem = {
        RecallItem(
            term: "Hippocampus",
            note: "Memory consolidation"
        )
    }()

    static let itemWithoutNote: RecallItem = {
        RecallItem(term: "Neuroplasticity")
    }()

    static let itemDetail: RecallItem = {
        let item = RecallItem(
            term: "Hippocampus",
            note: "Encodes and consolidates episodic memory."
        )
        item.createdAt = Calendar.current.date(byAdding: .day, value: -12, to: Date()) ?? Date()

        let first = Review(rating: .missed, recalledText: "Struggled to remember the exact role.")
        first.reviewedAt = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        first.item = item

        let second = Review(rating: .partial, recalledText: "Memory region involved in navigation and encoding.")
        second.reviewedAt = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        second.item = item

        let third = Review(rating: .nailed, recalledText: "Critical for forming and consolidating declarative memories.")
        third.reviewedAt = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        third.item = item

        item.reviews = [first, second, third]
        return item
    }()

    private static let sampleItems: [RecallItem] = {
        let todayNew = RecallItem(
            term: "System Design",
            note: "How to approach scalable architecture questions"
        )
        todayNew.createdAt = Date()

        let todayDue = RecallItem(
            term: "CAP Theorem",
            note: "Consistency, Availability, Partition tolerance trade-off"
        )
        todayDue.createdAt = Date()
        let todayReview = Review(rating: .partial)
        todayReview.reviewedAt = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        todayReview.item = todayDue
        todayDue.reviews = [todayReview]

        let olderDue = RecallItem(
            term: "MQTT Protocol",
            note: "Lightweight pub/sub messaging for constrained devices"
        )
        olderDue.createdAt = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        let olderReview = Review(rating: .missed)
        olderReview.reviewedAt = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        olderReview.item = olderDue
        olderDue.reviews = [olderReview]

        let mastered = RecallItem(
            term: "Action Potential",
            note: "Electrical impulse that travels along a neuron"
        )
        mastered.createdAt = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var masteredReviews: [Review] = []
        for dayOffset in [28, 21, 14, 7, 2] {
            let review = Review(rating: .nailed)
            review.reviewedAt = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            review.item = mastered
            masteredReviews.append(review)
        }
        mastered.reviews = masteredReviews

        return [todayNew, todayDue, olderDue, mastered]
    }()

    static let sampleCollections: [RecallCollection] = {
        let iot = RecallCollection(name: "IoT Interview Prep", color: .teal)
        let sysdesign = RecallCollection(name: "System Design", color: .indigo)
        let neuro = RecallCollection(name: "Neuroscience", color: .purple)
        let empty = RecallCollection(name: "Algorithms", color: .orange)

        iot.items = Array(sampleItems.prefix(2))
        sysdesign.items = Array(sampleItems.suffix(2))
        neuro.items = [sampleItems[0]]

        return [iot, sysdesign, neuro, empty]
    }()

    private static let sampleReviews: [Review] = {
        sampleItems.flatMap { $0.reviews ?? [] }
    }()
}
