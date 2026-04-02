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
    /// The main targeted feedback category returned by the AI.
    var aiPrimaryFeedbackCategoryValue: String?
    /// An optional secondary targeted feedback category returned by the AI.
    var aiSecondaryFeedbackCategoryValue: String?
    /// True when the AI judged the main concept as correctly recalled.
    var aiCoreIdeaCorrect: Bool?
    /// Important concepts the AI flagged as missing.
    var aiMissingConcepts: String?
    /// Incorrect claims or confusions the AI detected.
    var aiIncorrectClaims: String?
    /// The AI's self-reported confidence in its grade.
    var aiConfidenceValue: String?
    /// True when the AI suggested the item should come back soon.
    var aiShouldResurfaceSoon: Bool?

    /// Typed access to the stored rating value.
    var rating: Rating {
        get { Rating(rawValue: ratingValue) ?? .forgot }
        set { ratingValue = newValue.rawValue }
    }

    var aiConfidence: GradingConfidence? {
        get {
            guard let aiConfidenceValue else { return nil }
            return GradingConfidence(rawValue: aiConfidenceValue)
        }
        set {
            aiConfidenceValue = newValue?.rawValue
        }
    }

    var aiPrimaryFeedbackCategory: FeedbackCategory? {
        get {
            guard let aiPrimaryFeedbackCategoryValue else { return nil }
            return FeedbackCategory(rawValue: aiPrimaryFeedbackCategoryValue)
        }
        set {
            aiPrimaryFeedbackCategoryValue = newValue?.rawValue
        }
    }

    var aiSecondaryFeedbackCategory: FeedbackCategory? {
        get {
            guard let aiSecondaryFeedbackCategoryValue else { return nil }
            return FeedbackCategory(rawValue: aiSecondaryFeedbackCategoryValue)
        }
        set {
            aiSecondaryFeedbackCategoryValue = newValue?.rawValue
        }
    }

    init(rating: Rating, recalledText: String? = nil) {
        self.id = UUID()
        self.reviewedAt = Date()
        self.ratingValue = rating.rawValue
        self.recalledText = recalledText
    }
}
