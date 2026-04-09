import Foundation
import FoundationModels

@Generable
private struct AIAnswerResponse {
    @Guide(description: "A concise definition of the term in one sentence, plain language, no bullet marker.")
    var definition: String

    @Guide(description: "One key concept or distinction in one sentence, plain language, no bullet marker.")
    var keyConcept: String

    @Guide(description: "Why the term matters in one sentence, plain language, no bullet marker.")
    var whyItMatters: String
}

enum AIAnswerService {
    enum AIAnswerError: LocalizedError {
        case modelUnavailable

        var errorDescription: String? {
            switch self {
            case .modelUnavailable:
                return "On-device AI is not available on this device."
            }
        }
    }

    static func generateAnswer(term: String, context: String?) async throws -> String {
        let model = SystemLanguageModel.default

        guard model.isAvailable else {
            throw AIAnswerError.modelUnavailable
        }

        let session = LanguageModelSession(model: model)
        let response = try await session.respond(
            to: prompt(term: term, context: context),
            generating: AIAnswerResponse.self
        )

        return """
        - Definition: \(clean(response.content.definition))
        - Key concept: \(clean(response.content.keyConcept))
        - Why it matters: \(clean(response.content.whyItMatters))
        """
    }

    private static func prompt(term: String, context: String?) -> String {
        let contextLine: String
        if let context, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contextLine = "User context: \(context)"
        } else {
            contextLine = "User context: none provided"
        }

        return """
        Generate a short study answer for a spaced-repetition card.

        Term: \(term)
        \(contextLine)

        Rules:
        - Use the term and context to explain the concept accurately.
        - Return content for exactly three bullets only.
        - Keep each field to one short sentence.
        - Do not add markdown bullets, numbering, or extra commentary.
        - Write for fast recall, not for exhaustive teaching.
        - The three fields are: definition, keyConcept, whyItMatters.
        """
    }

    // MARK: - Gap suggestions

    /// Returns up to three sub-concepts missing from the user's answer, or an empty array
    /// if the answer is already comprehensive. Never throws for "no gaps found" — that's
    /// represented as an empty array.
    static func generateGaps(term: String, answer: String) async throws -> [String] {
        let model = SystemLanguageModel.default

        guard model.isAvailable else {
            throw AIAnswerError.modelUnavailable
        }

        let session = LanguageModelSession(model: model)
        let response = try await session.respond(
            to: gapPrompt(term: term, answer: answer),
            generating: AIGapResponse.self
        )

        return [response.content.gap1, response.content.gap2, response.content.gap3]
            .map { clean($0) }
            .filter { !$0.isEmpty && $0.lowercased() != "none" }
    }

    private static func gapPrompt(term: String, answer: String) -> String {
        """
        You are helping a student identify gaps in their recall answer for a spaced-repetition card.

        Term: \(term)
        Student's answer: \(answer)

        Task: Identify up to three important sub-concepts, angles, or distinctions that the student's \
        answer is missing or significantly underselling. Focus on what would meaningfully improve recall.

        Rules:
        - Each gap is one short sentence describing what is missing.
        - Do not repeat anything already in the student's answer.
        - If the answer is already comprehensive, return "none" for unused fields.
        - Do not add markdown, bullets, or numbering.
        - Write for a student who wants to improve their answer, not a critic.
        """
    }

    private static func clean(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@Generable
private struct AIGapResponse {
    @Guide(description: "The most important sub-concept missing from the student's answer. One sentence. Write 'none' if not applicable.")
    var gap1: String

    @Guide(description: "A second missing sub-concept. One sentence. Write 'none' if not applicable.")
    var gap2: String

    @Guide(description: "A third missing sub-concept. One sentence. Write 'none' if not applicable.")
    var gap3: String
}
