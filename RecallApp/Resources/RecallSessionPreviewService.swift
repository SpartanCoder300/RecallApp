import Foundation

enum RecallSessionPreviewService {
    static let sessionItems: [RecallItem] = [
        RecallItem(
            term: "CAP Theorem",
            note: "Consistency, availability, and partition tolerance cannot all be guaranteed during a network partition.",
            cachedAIAnswerText: """
            - Definition: CAP theorem describes the tradeoff between consistency, availability, and partition tolerance.
            - Key concept: During a partition, a distributed system must prioritize consistency or availability.
            - Why it matters: It frames real system design tradeoffs instead of pretending every distributed system can maximize all three.
            """
        ),
        RecallItem(
            term: "Hippocampus",
            note: "Supports the formation and consolidation of episodic memories."
        )
    ]
}
