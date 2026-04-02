import Foundation
import FoundationModels

// MARK: - GradingResult

/// The output of an AI grading pass for a single review attempt.
struct GradingResult {
    let suggestedRating: Rating
    /// A short explanation of why that rating was suggested, shown to the user.
    let reasoning: String
}

// MARK: - Generable response type

/// Internal structured output type consumed by the Foundation Models session.
@Generable
private struct GradingResponse {
    /// The suggested rating. Must be one of: "Forgot", "Hard", "Easy".
    @Guide(description: "One of: Forgot, Hard, Easy")
    var rating: String

    /// Exactly one concise sentence explaining the rating to the user.
    @Guide(description: "Exactly one concise sentence, 18 words max. Focus on whether the user captured the core idea and any important missing detail. Do not rewrite the full answer. Address the user directly.")
    var reasoning: String
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
        collectionName: String? = nil
    ) async throws -> GradingResult {
        // Fast path: empty input is always Forgot — no model call needed.
        guard !recalledText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return GradingResult(suggestedRating: .forgot, reasoning: "You didn't enter a response.")
        }

        let model = SystemLanguageModel.default

        guard model.isAvailable else {
            throw GradingError.modelUnavailable
        }

        let session = LanguageModelSession(model: model)
        let prompt = buildPrompt(recalledText: recalledText, term: term, note: note, collectionName: collectionName)

        let response = try await session.respond(
            to: prompt,
            generating: GradingResponse.self
        )

        guard let rating = Rating(rawValue: response.content.rating) else {
            throw GradingError.invalidRatingResponse(response.content.rating)
        }

        return GradingResult(suggestedRating: rating, reasoning: response.content.reasoning)
    }

    // MARK: Prompt Construction

    private static func buildPrompt(
        recalledText: String,
        term: String,
        note: String?,
        collectionName: String?
    ) -> String {
        let domainLine = collectionName.map { "Subject area: \($0)\n" } ?? ""
        let ratingCriteria = """
            - Forgot: The core idea is missing, meaningfully wrong, or shows no real understanding.
            - Hard: The core idea is mostly there, but one or more important details, distinctions, or qualifiers are missing or wrong.
            - Easy: The core idea is correct and the important details are present. Minor wording differences, paraphrasing, or different phrasing are fine.
            """
        let outputRules = """
            Return:
            - rating: Forgot, Hard, or Easy
            - reasoning: exactly one sentence, 18 words max, saying whether the user got the core idea and what important detail was missing, if any

            Do not rewrite the full correct answer. Do not provide a full corrected response. Do not use more than one sentence. Do not add encouragement, hedging, or extra commentary. Address the user directly.
            """

        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return """
            You are grading a spaced-repetition flashcard recall attempt.

            \(domainLine)Card term: \(term)
            Correct answer: \(note)
            User's answer: \(recalledText)

            Grade based on meaning, not wording. Do not expect the user's answer to match the stored answer textually.
            First decide whether the user captured the core idea. Then decide whether any important details were missing.

            Rate how well the user's answer matches the correct answer:
            \(ratingCriteria)

            \(outputRules)
            """
        } else {
            return """
            You are grading a spaced-repetition flashcard recall attempt.

            \(domainLine)Card term: \(term)
            (No stored answer — use your general knowledge to evaluate correctness.)
            User's answer: \(recalledText)

            Grade based on meaning, not wording. Do not expect the user's answer to match a textbook phrasing.
            First decide whether the user captured the core idea. Then decide whether any important details were missing.

            Based on what a correct answer for "\(term)" would typically be, rate the user's response:
            \(ratingCriteria)

            \(outputRules)
            """
        }
    }
}
