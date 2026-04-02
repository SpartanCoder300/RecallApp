import Foundation

enum GradingConfidence: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum FeedbackCategory: String, Codable, CaseIterable {
    case mainIdeaCaptured = "Main Idea Captured"
    case causalMechanismMissing = "Causal Mechanism Missing"
    case confusedConcepts = "Confused Concepts"
    case exceptionOmitted = "Exception Omitted"
    case importantQualifierMissing = "Important Qualifier Missing"
    case criticalDetailMissing = "Critical Detail Missing"

    var title: String { rawValue }
}

/// The output of an AI grading pass for a single review attempt.
struct GradingResult {
    let suggestedRating: Rating
    /// A short explanation of why that rating was suggested, shown to the user.
    let reasoning: String
    /// The main coaching category for this answer.
    let primaryFeedbackCategory: FeedbackCategory
    /// An optional secondary coaching category.
    let secondaryFeedbackCategory: FeedbackCategory?
    /// Whether the user's answer captured the main concept.
    let coreIdeaCorrect: Bool
    /// Important concepts the user omitted, if any.
    let missingConcepts: String?
    /// Meaningfully wrong claims that should be corrected, if any.
    let incorrectClaims: String?
    /// How confident the model is in the grading decision.
    let confidence: GradingConfidence
    /// Whether this answer should be surfaced again soon due to missing or incorrect details.
    let shouldResurfaceSoon: Bool
}

struct GradingJSONResponse: Decodable {
    let rating: String
    let reasoning: String
    let primaryFeedbackCategory: String
    let secondaryFeedbackCategory: String
    let coreIdeaCorrect: Bool
    let missingConcepts: String
    let incorrectClaims: String
    let confidence: String
    let shouldResurfaceSoon: Bool
}

enum AnswerGradingPromptBuilder {
    static func buildPrompt(
        recalledText: String,
        term: String,
        note: String?,
        keyFacts: [String],
        acceptedSynonyms: [String],
        commonConfusions: [String],
        collectionName: String?
    ) -> String {
        let domainLine = collectionName.map { "Subject area: \($0)\n" } ?? ""
        let keyFactsSection = bulletSection(title: "Key facts to check for", entries: keyFacts)
        let synonymsSection = bulletSection(title: "Accepted synonyms or alternate phrasings", entries: acceptedSynonyms)
        let confusionsSection = bulletSection(title: "Common confusions to penalize if stated or implied", entries: commonConfusions)
        let ratingCriteria = """
            - Forgot: Use Forgot when the answer is vague, generic, mostly missing, meaningfully wrong, or shows familiarity without stating the actual claim. If the user does not clearly state the core idea, choose Forgot.
            - Hard: Use Hard only when the core idea is clearly correct but one or more important details, distinctions, or qualifiers are missing or wrong.
            - Easy: Use Easy when the core idea is clearly correct and the important details needed for this card are present. Concise answers can still be Easy if they state the essential claim correctly.
            """
        let decisionGuardrails = """
            Decision guardrails:
            - Do not use Hard as a default middle option.
            - If the answer is brief but clearly correct on the core claim and key condition, choose Easy.
            - If the answer sounds like recognition, hand-waving, or partial familiarity without the actual concept, choose Forgot.
            - Reserve Hard for answers that are substantively right but incomplete.
            - A stated confusion or reversed concept should be Forgot, not Hard.
            """
        let outputRules = """
            Return valid JSON with exactly these keys:
            - rating
            - reasoning
            - primaryFeedbackCategory
            - secondaryFeedbackCategory
            - coreIdeaCorrect
            - missingConcepts
            - incorrectClaims
            - confidence
            - shouldResurfaceSoon

            Rules:
            - rating: Forgot, Hard, or Easy
            - reasoning: exactly one sentence, 18 words max, using the feedback categories to say what was right or wrong
            - primaryFeedbackCategory: choose the best main coaching category
            - secondaryFeedbackCategory: choose one supporting category or return empty string
            - coreIdeaCorrect: true if the main idea is correct
            - missingConcepts: short phrase for the main missing detail, or empty string
            - incorrectClaims: short phrase for the main incorrect claim, or empty string
            - confidence: Low, Medium, or High
            - shouldResurfaceSoon: true if this answer indicates the card should come back soon

            Do not rewrite the full correct answer. Do not provide a full corrected response. Do not use more than one sentence. Do not add encouragement, hedging, or extra commentary. Address the user directly.
            """
        let feedbackCategories = """
            Feedback category definitions:
            - Main Idea Captured: the core idea is correct even if details need work
            - Causal Mechanism Missing: the process, why, or how is missing
            - Confused Concepts: the answer mixes this concept up with another
            - Exception Omitted: the main rule is there but an important exception or boundary condition is missing
            - Important Qualifier Missing: the answer needs a limiting qualifier, condition, or distinction
            - Critical Detail Missing: a key fact is absent but not specifically a mechanism, exception, or qualifier
            """

        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return """
            You are grading a spaced-repetition flashcard recall attempt.

            \(domainLine)Card term: \(term)
            Correct answer: \(note)
            User's answer: \(recalledText)

            Grade based on meaning, not wording. Do not expect the user's answer to match the stored answer textually.
            First decide whether the user captured the core idea. Then decide whether any important details were missing.
            \(keyFactsSection)\(synonymsSection)\(confusionsSection)

            \(feedbackCategories)

            Rate how well the user's answer matches the correct answer:
            \(ratingCriteria)
            \(decisionGuardrails)

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
            \(keyFactsSection)\(synonymsSection)\(confusionsSection)

            \(feedbackCategories)

            Based on what a correct answer for "\(term)" would typically be, rate the user's response:
            \(ratingCriteria)
            \(decisionGuardrails)

            \(outputRules)
            """
        }
    }

    static func normalized(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func bulletSection(title: String, entries: [String]) -> String {
        guard !entries.isEmpty else { return "" }
        let bullets = entries.map { "- \($0)" }.joined(separator: "\n")
        return """

        \(title):
        \(bullets)
        """
    }
}
