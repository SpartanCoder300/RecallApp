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
            note: "Memory consolidation",
            keyFactsText: "Encodes episodic memory\nSupports consolidation",
            acceptedSynonymsText: "Memory formation",
            commonConfusionsText: "Stores all memories permanently"
        )
    }()

    static let itemWithoutNote: RecallItem = {
        RecallItem(term: "Neuroplasticity")
    }()

    static let itemDetail: RecallItem = {
        let item = RecallItem(
            term: "Hippocampus",
            note: "Encodes and consolidates episodic memory.",
            keyFactsText: "Encodes new episodic memories\nSupports consolidation into long-term memory",
            acceptedSynonymsText: "Declarative memory formation",
            commonConfusionsText: "Primary motor control center\nPermanent storage location for every memory"
        )
        item.createdAt = Calendar.current.date(byAdding: .day, value: -12, to: Date()) ?? Date()

        let first = Review(rating: .forgot, recalledText: "Struggled to remember the exact role.")
        first.reviewedAt = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        first.item = item

        let second = Review(rating: .hard, recalledText: "Memory region involved in navigation and encoding.")
        second.reviewedAt = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        second.item = item

        let third = Review(rating: .easy, recalledText: "Critical for forming and consolidating declarative memories.")
        third.reviewedAt = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        third.item = item

        item.reviews = [first, second, third]
        return item
    }()

    private static let sampleItems: [RecallItem] = {
        let todayNew = RecallItem(
            term: "System Design",
            note: "How to approach scalable architecture questions",
            keyFactsText: "Clarify requirements\nIdentify bottlenecks\nDiscuss trade-offs"
        )
        todayNew.createdAt = Date()

        let todayDue = RecallItem(
            term: "CAP Theorem",
            note: "Consistency, Availability, Partition tolerance trade-off",
            keyFactsText: "Network partition is the forcing condition\nCannot guarantee both consistency and availability during a partition",
            commonConfusionsText: "You can always have all three\nCAP is about normal operation without partitions"
        )
        todayDue.createdAt = Date()
        let todayReview = Review(rating: .hard)
        todayReview.reviewedAt = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        todayReview.item = todayDue
        todayDue.reviews = [todayReview]

        let olderDue = RecallItem(
            term: "MQTT Protocol",
            note: "Lightweight pub/sub messaging for constrained devices",
            keyFactsText: "Publish/subscribe model\nDesigned for constrained devices and unreliable networks",
            acceptedSynonymsText: "Lightweight messaging protocol",
            commonConfusionsText: "Request-response protocol like REST"
        )
        olderDue.createdAt = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        let olderReview = Review(rating: .forgot)
        olderReview.reviewedAt = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        olderReview.item = olderDue
        olderDue.reviews = [olderReview]

        let mastered = RecallItem(
            term: "Action Potential",
            note: "Electrical impulse that travels along a neuron",
            keyFactsText: "All-or-none electrical signal\nTravels along the neuron membrane"
        )
        mastered.createdAt = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var masteredReviews: [Review] = []
        for dayOffset in [28, 21, 14, 7, 2] {
            let review = Review(rating: .easy)
            review.reviewedAt = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            review.item = mastered
            masteredReviews.append(review)
        }
        mastered.reviews = masteredReviews

        return [todayNew, todayDue, olderDue, mastered]
    }()

    private static let sampleReviews: [Review] = {
        sampleItems.flatMap { $0.reviews ?? [] }
    }()
}
