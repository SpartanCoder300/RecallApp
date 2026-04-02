#!/usr/bin/env swift

import Foundation

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

struct Prediction: Codable {
    let id: String
    let suggestedRating: String
    let primaryFeedbackCategory: String?
    let secondaryFeedbackCategory: String?
}

struct DomainSummary {
    var total = 0
    var correct = 0
}

enum EvaluationError: Error, CustomStringConvertible {
    case usage(String)
    case invalidArguments(String)
    case duplicateCaseID(String)
    case duplicatePredictionID(String)
    case fileReadFailed(String)
    case fileWriteFailed(String)
    case jsonDecodeFailed(String)

    var description: String {
        switch self {
        case .usage(let message),
             .invalidArguments(let message),
             .duplicateCaseID(let message),
             .duplicatePredictionID(let message),
             .fileReadFailed(let message),
             .fileWriteFailed(let message),
             .jsonDecodeFailed(let message):
            return message
        }
    }
}

func main() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())

    guard !arguments.isEmpty else {
        throw EvaluationError.usage(usageText)
    }

    var datasetPath: String?
    var predictionsPath: String?
    var templateOutputPath: String?
    var expectedOutputPath: String?

    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--dataset":
            index += 1
            datasetPath = try value(after: index, in: arguments, flag: argument)
        case "--predictions":
            index += 1
            predictionsPath = try value(after: index, in: arguments, flag: argument)
        case "--write-template":
            index += 1
            templateOutputPath = try value(after: index, in: arguments, flag: argument)
        case "--write-expected":
            index += 1
            expectedOutputPath = try value(after: index, in: arguments, flag: argument)
        case "--help", "-h":
            print(usageText)
            return
        default:
            throw EvaluationError.invalidArguments("Unknown argument: \(argument)\n\n\(usageText)")
        }
        index += 1
    }

    guard let datasetPath else {
        throw EvaluationError.invalidArguments("Missing required argument: --dataset\n\n\(usageText)")
    }

    let cases = try loadCases(from: datasetPath)

    if let templateOutputPath {
        try writePredictionsTemplate(for: cases, to: templateOutputPath)
        print("Wrote blank predictions template to \(templateOutputPath)")
    }

    if let expectedOutputPath {
        try writeExpectedPredictions(for: cases, to: expectedOutputPath)
        print("Wrote perfect-baseline predictions to \(expectedOutputPath)")
    }

    guard let predictionsPath else {
        if templateOutputPath != nil || expectedOutputPath != nil {
            return
        }
        throw EvaluationError.invalidArguments("Missing required argument: --predictions\n\n\(usageText)")
    }

    let predictions = try loadPredictions(from: predictionsPath)
    try reportMetrics(cases: cases, predictions: predictions)
}

func value(after index: Int, in arguments: [String], flag: String) throws -> String {
    guard index < arguments.count else {
        throw EvaluationError.invalidArguments("Missing value after \(flag)")
    }
    return arguments[index]
}

func loadCases(from path: String) throws -> [EvaluationCase] {
    let data = try readFile(at: path)
    let cases: [EvaluationCase]

    do {
        cases = try JSONDecoder().decode([EvaluationCase].self, from: data)
    } catch {
        throw EvaluationError.jsonDecodeFailed("Failed to decode evaluation dataset at \(path): \(error)")
    }

    var ids = Set<String>()
    for evaluationCase in cases {
        if !ids.insert(evaluationCase.id).inserted {
            throw EvaluationError.duplicateCaseID("Duplicate evaluation case id: \(evaluationCase.id)")
        }
    }

    return cases
}

func loadPredictions(from path: String) throws -> [Prediction] {
    let data = try readFile(at: path)
    let predictions: [Prediction]

    do {
        predictions = try JSONDecoder().decode([Prediction].self, from: data)
    } catch {
        throw EvaluationError.jsonDecodeFailed("Failed to decode predictions file at \(path): \(error)")
    }

    var ids = Set<String>()
    for prediction in predictions {
        if !ids.insert(prediction.id).inserted {
            throw EvaluationError.duplicatePredictionID("Duplicate prediction id: \(prediction.id)")
        }
    }

    return predictions
}

func readFile(at path: String) throws -> Data {
    guard let data = FileManager.default.contents(atPath: path) else {
        throw EvaluationError.fileReadFailed("Could not read file at \(path)")
    }
    return data
}

func writePredictionsTemplate(for cases: [EvaluationCase], to path: String) throws {
    let template = cases.map {
        Prediction(id: $0.id, suggestedRating: "", primaryFeedbackCategory: nil, secondaryFeedbackCategory: nil)
    }
    try writeJSON(template, to: path)
}

func writeExpectedPredictions(for cases: [EvaluationCase], to path: String) throws {
    let predictions = cases.map {
        Prediction(
            id: $0.id,
            suggestedRating: $0.expectedRating,
            primaryFeedbackCategory: $0.expectedPrimaryFeedbackCategory,
            secondaryFeedbackCategory: $0.expectedSecondaryFeedbackCategory
        )
    }
    try writeJSON(predictions, to: path)
}

func writeJSON<T: Encodable>(_ value: T, to path: String) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    do {
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    } catch {
        throw EvaluationError.fileWriteFailed("Failed to write file at \(path): \(error)")
    }
}

func reportMetrics(cases: [EvaluationCase], predictions: [Prediction]) throws {
    let predictionMap = Dictionary(uniqueKeysWithValues: predictions.map { ($0.id, $0) })

    var matchedCount = 0
    var ratingCorrectCount = 0
    var falseEasyCount = 0
    var falseForgotCount = 0
    var easyOpportunities = 0
    var forgotOpportunities = 0
    var primaryFeedbackMatches = 0
    var primaryFeedbackEvaluated = 0
    var confusionMatrix: [String: [String: Int]] = [:]
    var domainSummaries: [String: DomainSummary] = [:]
    var missingPredictionIDs: [String] = []

    for evaluationCase in cases {
        guard let prediction = predictionMap[evaluationCase.id] else {
            missingPredictionIDs.append(evaluationCase.id)
            continue
        }

        matchedCount += 1

        let expectedRating = evaluationCase.expectedRating
        let predictedRating = prediction.suggestedRating
        let ratingCorrect = expectedRating == predictedRating

        if ratingCorrect {
            ratingCorrectCount += 1
        }

        if expectedRating != "Easy" {
            easyOpportunities += 1
            if predictedRating == "Easy" {
                falseEasyCount += 1
            }
        }

        if expectedRating != "Forgot" {
            forgotOpportunities += 1
            if predictedRating == "Forgot" {
                falseForgotCount += 1
            }
        }

        if let primaryFeedbackCategory = prediction.primaryFeedbackCategory,
           !primaryFeedbackCategory.isEmpty {
            primaryFeedbackEvaluated += 1
            if primaryFeedbackCategory == evaluationCase.expectedPrimaryFeedbackCategory {
                primaryFeedbackMatches += 1
            }
        }

        confusionMatrix[expectedRating, default: [:]][predictedRating, default: 0] += 1

        var summary = domainSummaries[evaluationCase.domain, default: DomainSummary()]
        summary.total += 1
        if ratingCorrect {
            summary.correct += 1
        }
        domainSummaries[evaluationCase.domain] = summary
    }

    let coverage = rate(numerator: matchedCount, denominator: cases.count)
    let ratingAccuracy = rate(numerator: ratingCorrectCount, denominator: matchedCount)
    let falseEasyRate = rate(numerator: falseEasyCount, denominator: easyOpportunities)
    let falseForgotRate = rate(numerator: falseForgotCount, denominator: forgotOpportunities)
    let primaryFeedbackAccuracy = rate(numerator: primaryFeedbackMatches, denominator: primaryFeedbackEvaluated)

    print("AI Grading Evaluation")
    print("=====================")
    print("Cases in dataset: \(cases.count)")
    print("Predictions provided: \(predictions.count)")
    print("Coverage: \(formatPercent(coverage)) (\(matchedCount)/\(cases.count))")
    print("Rating accuracy: \(formatPercent(ratingAccuracy)) (\(ratingCorrectCount)/\(matchedCount))")
    print("False easy rate: \(formatPercent(falseEasyRate)) (\(falseEasyCount)/\(easyOpportunities))")
    print("False forgot rate: \(formatPercent(falseForgotRate)) (\(falseForgotCount)/\(forgotOpportunities))")

    if primaryFeedbackEvaluated > 0 {
        print("Primary feedback accuracy: \(formatPercent(primaryFeedbackAccuracy)) (\(primaryFeedbackMatches)/\(primaryFeedbackEvaluated))")
    } else {
        print("Primary feedback accuracy: not evaluated")
    }

    print("")
    print("Confusion Matrix")
    print("----------------")
    let orderedRatings = ["Forgot", "Hard", "Easy"]
    let header = ["Expected \\ Predicted"] + orderedRatings
    print(header.joined(separator: "\t"))
    for expected in orderedRatings {
        let row = orderedRatings.map { String(confusionMatrix[expected]?[$0] ?? 0) }
        print(([expected] + row).joined(separator: "\t"))
    }

    print("")
    print("Per-Domain Accuracy")
    print("-------------------")
    for domain in domainSummaries.keys.sorted() {
        let summary = domainSummaries[domain] ?? DomainSummary()
        let accuracy = rate(numerator: summary.correct, denominator: summary.total)
        print("\(domain): \(formatPercent(accuracy)) (\(summary.correct)/\(summary.total))")
    }

    if !missingPredictionIDs.isEmpty {
        print("")
        print("Missing Predictions")
        print("-------------------")
        for id in missingPredictionIDs.sorted() {
            print(id)
        }
    }
}

func rate(numerator: Int, denominator: Int) -> Double {
    guard denominator > 0 else { return 0 }
    return Double(numerator) / Double(denominator)
}

func formatPercent(_ value: Double) -> String {
    String(format: "%.1f%%", value * 100)
}

let usageText = """
Usage:
  swift scripts/evaluate_grading.swift --dataset <dataset.json> --predictions <predictions.json>
  swift scripts/evaluate_grading.swift --dataset <dataset.json> --write-template <output.json>
  swift scripts/evaluate_grading.swift --dataset <dataset.json> --write-expected <output.json>

Prediction schema:
  [
    {
      "id": "case-id",
      "suggestedRating": "Forgot | Hard | Easy",
      "primaryFeedbackCategory": "optional category",
      "secondaryFeedbackCategory": "optional category"
    }
  ]
"""

do {
    try main()
} catch let error as EvaluationError {
    fputs("\(error)\n", stderr)
    exit(1)
} catch {
    fputs("Unexpected error: \(error)\n", stderr)
    exit(1)
}
