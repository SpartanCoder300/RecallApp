import Foundation
import FoundationModels

struct EvaluationCase: Decodable {
    let id: String
    let domain: String
    let term: String
    let note: String
    let keyFacts: [String]
    let acceptedSynonyms: [String]
    let commonConfusions: [String]
    let recalledText: String
    let expectedRating: String
    let expectedPrimaryFeedbackCategory: String
    let expectedSecondaryFeedbackCategory: String?
}

struct Prediction: Encodable {
    let id: String
    let suggestedRating: String
    let primaryFeedbackCategory: String?
    let secondaryFeedbackCategory: String?
}

enum RunnerError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case readFailed(String)
    case decodeFailed(String)
    case encodeFailed(String)
    case writeFailed(String)
    case modelUnavailable

    var description: String {
        switch self {
        case .invalidArguments(let message),
             .readFailed(let message),
             .decodeFailed(let message),
             .encodeFailed(let message),
             .writeFailed(let message):
            return message
        case .modelUnavailable:
            return "System language model is unavailable on this machine. The live grading runner cannot execute."
        }
    }
}

func value(after index: Int, in arguments: [String], flag: String) throws -> String {
    guard index < arguments.count else {
        throw RunnerError.invalidArguments("Missing value after \(flag)")
    }
    return arguments[index]
}

func loadCases(from path: String) throws -> [EvaluationCase] {
    guard let data = FileManager.default.contents(atPath: path) else {
        throw RunnerError.readFailed("Could not read evaluation dataset at \(path)")
    }

    do {
        return try JSONDecoder().decode([EvaluationCase].self, from: data)
    } catch {
        throw RunnerError.decodeFailed("Failed to decode evaluation dataset at \(path): \(error)")
    }
}

func writePredictions(_ predictions: [Prediction], to path: String) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let data: Data
    do {
        data = try encoder.encode(predictions)
    } catch {
        throw RunnerError.encodeFailed("Failed to encode predictions: \(error)")
    }

    do {
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    } catch {
        throw RunnerError.writeFailed("Failed to write predictions to \(path): \(error)")
    }
}

@main
struct RunGradingEval {
    static func main() async {
        do {
            try await run()
        } catch let error as RunnerError {
            fputs("\(error)\n", stderr)
            exit(1)
        } catch {
            fputs("Unexpected error: \(error)\n", stderr)
            exit(1)
        }
    }

    static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        var datasetPath = "docs/ai-grading-eval-dataset.json"
        var predictionsOutPath = "/tmp/ai-grading-live-predictions.json"
        var limit: Int?

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--dataset":
                index += 1
                datasetPath = try value(after: index, in: arguments, flag: argument)
            case "--predictions-out":
                index += 1
                predictionsOutPath = try value(after: index, in: arguments, flag: argument)
            case "--limit":
                index += 1
                let rawValue = try value(after: index, in: arguments, flag: argument)
                guard let parsed = Int(rawValue), parsed > 0 else {
                    throw RunnerError.invalidArguments("--limit must be a positive integer")
                }
                limit = parsed
            case "--help", "-h":
                print(usageText)
                return
            default:
                throw RunnerError.invalidArguments("Unknown argument: \(argument)\n\n\(usageText)")
            }
            index += 1
        }

        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw RunnerError.modelUnavailable
        }

        let session = LanguageModelSession(model: model)
        let cases = try loadCases(from: datasetPath)
        let casesToRun = limit.map { Array(cases.prefix($0)) } ?? cases
        var predictions: [Prediction] = []
        predictions.reserveCapacity(casesToRun.count)

        for (position, evaluationCase) in casesToRun.enumerated() {
            let prompt = AnswerGradingPromptBuilder.buildPrompt(
                recalledText: evaluationCase.recalledText,
                term: evaluationCase.term,
                note: evaluationCase.note,
                keyFacts: evaluationCase.keyFacts,
                acceptedSynonyms: evaluationCase.acceptedSynonyms,
                commonConfusions: evaluationCase.commonConfusions,
                collectionName: nil
            )

            let response: LanguageModelSession.Response<String>
            do {
                response = try await session.respond(to: prompt)
            } catch {
                throw RunnerError.decodeFailed("Generation failed for \(evaluationCase.id): \(error)")
            }

            let payload = try decodePayload(from: response.content, caseID: evaluationCase.id)
            let suggestedRating = try parseRating(payload.rating, caseID: evaluationCase.id)
            let primaryFeedbackCategory = try parseFeedbackCategory(payload.primaryFeedbackCategory, caseID: evaluationCase.id)
            let secondaryFeedbackCategory = try parseOptionalFeedbackCategory(payload.secondaryFeedbackCategory, caseID: evaluationCase.id)

            predictions.append(
                Prediction(
                    id: evaluationCase.id,
                    suggestedRating: suggestedRating.rawValue,
                    primaryFeedbackCategory: primaryFeedbackCategory.rawValue,
                    secondaryFeedbackCategory: secondaryFeedbackCategory?.rawValue
                )
            )

            let current = position + 1
            fputs("Graded \(current)/\(casesToRun.count): \(evaluationCase.id)\n", stderr)
        }

        try writePredictions(predictions, to: predictionsOutPath)
        print("Wrote live predictions to \(predictionsOutPath)")
    }
}

func decodePayload(from rawText: String, caseID: String) throws -> GradingJSONResponse {
    guard let data = extractJSONObject(from: rawText).data(using: .utf8) else {
        throw RunnerError.decodeFailed("Model output for \(caseID) was not valid UTF-8 JSON text.")
    }

    do {
        return try JSONDecoder().decode(GradingJSONResponse.self, from: data)
    } catch {
        throw RunnerError.decodeFailed("Failed to decode model JSON for \(caseID): \(error)\nRaw output:\n\(rawText)")
    }
}

func parseRating(_ rawValue: String, caseID: String) throws -> Rating {
    guard let rating = Rating(rawValue: rawValue) else {
        throw RunnerError.decodeFailed("Invalid rating '\(rawValue)' for \(caseID)")
    }
    return rating
}

func parseFeedbackCategory(_ rawValue: String, caseID: String) throws -> FeedbackCategory {
    guard let category = FeedbackCategory(rawValue: rawValue) else {
        throw RunnerError.decodeFailed("Invalid feedback category '\(rawValue)' for \(caseID)")
    }
    return category
}

func parseOptionalFeedbackCategory(_ rawValue: String, caseID: String) throws -> FeedbackCategory? {
    guard let normalized = AnswerGradingPromptBuilder.normalized(rawValue) else {
        return nil
    }

    guard let category = FeedbackCategory(rawValue: normalized) else {
        throw RunnerError.decodeFailed("Invalid secondary feedback category '\(normalized)' for \(caseID)")
    }
    return category
}

func extractJSONObject(from text: String) -> String {
    guard let start = text.firstIndex(of: "{"),
          let end = text.lastIndex(of: "}") else {
        return text
    }
    return String(text[start...end])
}

let usageText = """
Usage:
  swiftc RecallApp/Models/Rating.swift RecallApp/Services/AnswerGradingSupport.swift scripts/run_grading_eval_main.swift -o /tmp/run_grading_eval_exec

Options:
  --dataset <path>          Defaults to docs/ai-grading-eval-dataset.json
  --predictions-out <path>  Defaults to /tmp/ai-grading-live-predictions.json
  --limit <n>               Run only the first n benchmark cases
"""
