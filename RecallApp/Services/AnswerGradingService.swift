import Foundation
import FoundationModels

// MARK: - Generable response type

/// Internal structured output type consumed by the Foundation Models session.
@Generable
private struct GradingResponse {
    /// The suggested rating. Must be one of: "Forgot", "Hard", "Easy".
    @Guide(description: "One of: Forgot, Hard, Easy")
    var rating: String

    /// Exactly one concise sentence explaining the rating to the user.
    @Guide(description: "Exactly one concise sentence, 18 words max. Use the feedback categories to give specific coaching. Do not rewrite the full answer. Address the user directly.")
    var reasoning: String

    /// The main category of feedback to show the user.
    @Guide(description: "One of: Main Idea Captured, Causal Mechanism Missing, Confused Concepts, Exception Omitted, Important Qualifier Missing, Critical Detail Missing")
    var primaryFeedbackCategory: String

    /// Optional secondary category of feedback.
    @Guide(description: "One of: Main Idea Captured, Causal Mechanism Missing, Confused Concepts, Exception Omitted, Important Qualifier Missing, Critical Detail Missing. Empty string if none.")
    var secondaryFeedbackCategory: String

    /// Whether the main concept was recalled correctly.
    @Guide(description: "True if the user's answer captures the main concept. False otherwise.")
    var coreIdeaCorrect: Bool

    /// Missing ideas that prevented a stronger score.
    @Guide(description: "A short phrase naming the most important missing concept or detail. Empty string if nothing important is missing.")
    var missingConcepts: String

    /// Incorrect claims that should be corrected.
    @Guide(description: "A short phrase naming the most important wrong claim or confusion. Empty string if nothing meaningfully incorrect was stated.")
    var incorrectClaims: String

    /// Confidence in the grading judgment.
    @Guide(description: "One of: Low, Medium, High")
    var confidence: String

    /// Whether the item should be reviewed again soon because the answer was weak or unstable.
    @Guide(description: "True when the answer suggests this item should come back soon. False when the answer looks stable.")
    var shouldResurfaceSoon: Bool
}

// MARK: - AnswerGradingService

/// Grades a user's recalled answer against a RecallItem using an on-device language model.
///
/// - The `note` field is used as the authoritative answer when present.
/// - When `note` is absent the model infers a correct answer from the `term` alone.
/// - An empty `recalledText` bypasses the model entirely and returns `.forgot`.
enum AnswerGradingService {

    // MARK: Errors

    enum GradingError: Error {
        /// The model is not available on this device.
        case modelUnavailable
        /// The model returned a rating string that doesn't map to a known Rating.
        case invalidRatingResponse(String)
        /// The model returned a confidence string that doesn't map to a known confidence level.
        case invalidConfidenceResponse(String)
        /// The model returned a feedback category string that doesn't map to a known category.
        case invalidFeedbackCategoryResponse(String)
    }

    // MARK: Public API

    /// Grades the user's recalled answer.
    ///
    /// - Parameters:
    ///   - recalledText: What the user typed during the review session.
    ///   - term: The question or term on the card.
    ///   - note: The stored answer on the card, if any.
    ///   - collectionName: The name of the collection this card belongs to, if any.
    ///     Provides domain context (e.g. "Spanish Vocabulary", "Anatomy") so the model
    ///     can grade domain-specific nuance more accurately.
    /// - Returns: A `GradingResult` with a suggested `Rating` and reasoning.
    /// - Throws: `GradingError` if the model is unavailable or returns an unexpected response.
    static func grade(
        recalledText: String,
        term: String,
        note: String?,
        keyFacts: [String] = [],
        acceptedSynonyms: [String] = [],
        commonConfusions: [String] = [],
        collectionName: String? = nil
    ) async throws -> GradingResult {
        // Fast path: empty input is always Forgot — no model call needed.
        guard !recalledText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return GradingResult(
                suggestedRating: .forgot,
                reasoning: "You didn't enter a response.",
                primaryFeedbackCategory: .criticalDetailMissing,
                secondaryFeedbackCategory: nil,
                coreIdeaCorrect: false,
                missingConcepts: "No recall attempt",
                incorrectClaims: nil,
                confidence: .high,
                shouldResurfaceSoon: true
            )
        }

        let model = SystemLanguageModel.default

        guard model.isAvailable else {
            throw GradingError.modelUnavailable
        }

        let session = LanguageModelSession(model: model)
        let prompt = AnswerGradingPromptBuilder.buildPrompt(
            recalledText: recalledText,
            term: term,
            note: note,
            keyFacts: keyFacts,
            acceptedSynonyms: acceptedSynonyms,
            commonConfusions: commonConfusions,
            collectionName: collectionName
        )

        let response = try await session.respond(
            to: prompt,
            generating: GradingResponse.self
        )

        guard let rating = parsedRating(from: response.content.rating) else {
            throw GradingError.invalidRatingResponse(response.content.rating)
        }

        guard let confidence = parsedConfidence(from: response.content.confidence) else {
            throw GradingError.invalidConfidenceResponse(response.content.confidence)
        }

        guard let primaryFeedbackCategory = parsedFeedbackCategory(from: response.content.primaryFeedbackCategory) else {
            throw GradingError.invalidFeedbackCategoryResponse(response.content.primaryFeedbackCategory)
        }

        let secondaryFeedbackCategory = AnswerGradingPromptBuilder.normalized(response.content.secondaryFeedbackCategory)
            .flatMap(parsedFeedbackCategory(from:))

        if let secondaryCategoryText = AnswerGradingPromptBuilder.normalized(response.content.secondaryFeedbackCategory),
           secondaryFeedbackCategory == nil {
            throw GradingError.invalidFeedbackCategoryResponse(secondaryCategoryText)
        }

        return GradingResult(
            suggestedRating: rating,
            reasoning: response.content.reasoning,
            primaryFeedbackCategory: primaryFeedbackCategory,
            secondaryFeedbackCategory: secondaryFeedbackCategory,
            coreIdeaCorrect: response.content.coreIdeaCorrect,
            missingConcepts: AnswerGradingPromptBuilder.normalized(response.content.missingConcepts),
            incorrectClaims: AnswerGradingPromptBuilder.normalized(response.content.incorrectClaims),
            confidence: confidence,
            shouldResurfaceSoon: response.content.shouldResurfaceSoon
        )
    }

    private static func parsedRating(from rawValue: String) -> Rating? {
        let normalized = canonicalized(rawValue)
        return Rating.allCases.first { canonicalized($0.rawValue) == normalized }
    }

    private static func parsedConfidence(from rawValue: String) -> GradingConfidence? {
        let normalized = canonicalized(rawValue)
        return GradingConfidence.allCases.first { canonicalized($0.rawValue) == normalized }
    }

    private static func parsedFeedbackCategory(from rawValue: String) -> FeedbackCategory? {
        let normalized = canonicalized(rawValue)

        if let exactMatch = FeedbackCategory.allCases.first(where: { canonicalized($0.rawValue) == normalized }) {
            return exactMatch
        }

        switch normalized {
        case "mainidea", "mainideacorrect", "mainidearight", "coreideacaptured", "coreideacorrect":
            return .mainIdeaCaptured
        case "causalmechanism", "mechanismmissing", "causalmissing", "processmissing", "howmissing":
            return .causalMechanismMissing
        case "confusedconcept", "conceptconfusion", "mixedconcepts", "conceptsmixedup":
            return .confusedConcepts
        case "exceptionmissing", "exceptionomitted", "boundaryconditionmissing":
            return .exceptionOmitted
        case "importantqualifier", "qualifiermissing", "missingqualifier", "conditionmissing":
            return .importantQualifierMissing
        case "criticaldetail", "detailmissing", "missingdetail", "keydetailmissing":
            return .criticalDetailMissing
        default:
            return nil
        }
    }

    private static func canonicalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-z]", with: "", options: .regularExpression)
    }
}
