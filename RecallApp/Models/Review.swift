import Foundation
import SwiftData

@Model
final class Review {
    var id: UUID = UUID()
    var reviewedAt: Date = Date()
    /// Stored as a raw String — SwiftData cannot reliably persist custom Codable
    /// enums as stored properties on device. Access via the `rating` computed property.
    var ratingValue: String = Rating.forgot.rawValue
    var recalledText: String?

    var item: RecallItem?
    /// Reasoning text from the AI grader, if this review was AI-graded.
    var gradingReasoning: String?
    /// True if the rating was suggested (or confirmed) via AI grading.
    var wasAIGraded: Bool = false
    /// The rating the AI suggested, stored separately from the user's final rating.
    /// Nil when wasAIGraded is false. Compare against `ratingValue` to detect overrides.
    var aiSuggestedRating: String?

    /// Typed access to the stored rating value.
    var rating: Rating {
        get { Rating(rawValue: ratingValue) ?? .forgot }
        set { ratingValue = newValue.rawValue }
    }

    init(rating: Rating, recalledText: String? = nil) {
        self.id = UUID()
        self.reviewedAt = Date()
        self.ratingValue = rating.rawValue
        self.recalledText = recalledText
    }
}
