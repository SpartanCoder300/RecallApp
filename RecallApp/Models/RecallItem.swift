import Foundation
import SwiftData

@Model
final class RecallItem {
    // CloudKit requires all attributes to be optional or have stored default values.
    var id: UUID = UUID()
    /// The term, concept, or question the user wants to memorise.
    var term: String = ""
    /// Optional hint shown during recall if the user asks for help.
    var note: String?
    /// Canonical facts the user should include for a strong answer.
    var keyFactsText: String?
    /// Alternate terms or phrasings that should still count as correct.
    var acceptedSynonymsText: String?
    /// Common confusions the grader should watch for.
    var commonConfusionsText: String?
    var createdAt: Date = Date()

    // .cascade is not supported by CloudKit — SwiftData converts it to .nullify on remote.
    // Deleting a RecallItem must also explicitly delete its reviews in application code.
    @Relationship(deleteRule: .nullify, inverse: \Review.item)
    var reviews: [Review]?

    /// The collection this item belongs to. Always optional — items exist independently of collections.
    @Relationship
    var collection: RecallCollection?

    init(
        term: String,
        note: String? = nil,
        keyFactsText: String? = nil,
        acceptedSynonymsText: String? = nil,
        commonConfusionsText: String? = nil
    ) {
        self.id = UUID()
        self.term = term
        self.note = note
        self.keyFactsText = keyFactsText
        self.acceptedSynonymsText = acceptedSynonymsText
        self.commonConfusionsText = commonConfusionsText
        self.createdAt = Date()
    }

    // MARK: - Computed

    var reviewCount: Int { (reviews ?? []).count }

    var keyFacts: [String] {
        rubricEntries(from: keyFactsText)
    }

    var acceptedSynonyms: [String] {
        rubricEntries(from: acceptedSynonymsText)
    }

    var commonConfusions: [String] {
        rubricEntries(from: commonConfusionsText)
    }

    /// The date this item is next due for review.
    /// Items with no reviews return `Date.distantPast` (always due).
    var nextDueDate: Date {
        let records = (reviews ?? []).map { ReviewRecord(reviewedAt: $0.reviewedAt, rating: $0.rating) }
        return SchedulingEngine.nextDueDate(after: records, cadence: AppSettings.currentCadence)
    }

    /// Whether the item should appear in the current review queue.
    var isDue: Bool {
        switch status {
        case .new, .due: return true
        case .upcoming, .mastered: return false
        }
    }

    /// Human-readable status of this item right now.
    var status: ItemStatus {
        let reviews = reviews ?? []
        guard !reviews.isEmpty else { return .new }

        let records = reviews.map { ReviewRecord(reviewedAt: $0.reviewedAt, rating: $0.rating) }

        // Mastered: SM-2 interval has reached the cadence-specific mastery threshold.
        if SchedulingEngine.isMastered(after: records, cadence: AppSettings.currentCadence) {
            return .mastered
        }

        let now = Date()
        if nextDueDate <= now { return .due }

        let days = Calendar.current.dateComponents([.day], from: now, to: nextDueDate).day ?? 1
        return .upcoming(days: max(1, days))
    }

    private func rubricEntries(from text: String?) -> [String] {
        guard let text else { return [] }

        return text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
