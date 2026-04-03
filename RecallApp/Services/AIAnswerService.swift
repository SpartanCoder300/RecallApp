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

    private static func clean(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
