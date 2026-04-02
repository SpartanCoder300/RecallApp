#if DEBUG
import Foundation
import Observation

struct AIEvaluationCase: Decodable, Identifiable {
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

struct AIEvaluationPrediction: Codable {
    let id: String
    let suggestedRating: String
    let primaryFeedbackCategory: String?
    let secondaryFeedbackCategory: String?
}

struct AIEvaluationDomainSummary: Identifiable {
    let domain: String
    let correct: Int
    let total: Int

    var id: String { domain }
    var accuracy: Double { rate(numerator: correct, denominator: total) }
}

struct AIEvaluationMismatch: Identifiable {
    let id: String
    let domain: String
    let term: String
    let expectedRating: String
    let predictedRating: String
    let expectedPrimaryFeedbackCategory: String
    let predictedPrimaryFeedbackCategory: String?
}

struct AIEvaluationConfusionRow: Identifiable {
    let expectedRating: String
    let forgotCount: Int
    let hardCount: Int
    let easyCount: Int

    var id: String { expectedRating }
}

struct AIEvaluationFailure: Identifiable {
    let id: String
    let domain: String
    let term: String
    let errorDescription: String
}

struct AIEvaluationReport {
    let datasetCaseCount: Int
    let predictionsProvided: Int
    let matchedCount: Int
    let ratingCorrectCount: Int
    let falseEasyCount: Int
    let easyOpportunities: Int
    let falseForgotCount: Int
    let forgotOpportunities: Int
    let primaryFeedbackMatches: Int
    let primaryFeedbackEvaluated: Int
    let failures: [AIEvaluationFailure]
    let mismatches: [AIEvaluationMismatch]
    let domainSummaries: [AIEvaluationDomainSummary]
    let confusionRows: [AIEvaluationConfusionRow]

    var coverage: Double { rate(numerator: matchedCount, denominator: datasetCaseCount) }
    var ratingAccuracy: Double { rate(numerator: ratingCorrectCount, denominator: matchedCount) }
    var falseEasyRate: Double { rate(numerator: falseEasyCount, denominator: easyOpportunities) }
    var falseForgotRate: Double { rate(numerator: falseForgotCount, denominator: forgotOpportunities) }

    var primaryFeedbackAccuracy: Double? {
        guard primaryFeedbackEvaluated > 0 else { return nil }
        return rate(numerator: primaryFeedbackMatches, denominator: primaryFeedbackEvaluated)
    }
}

enum AIEvaluationRunSize: String, CaseIterable, Identifiable {
    case smoke5
    case smoke20
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smoke5:
            return "Smoke 5"
        case .smoke20:
            return "Smoke 20"
        case .full:
            return "Full 100"
        }
    }

    var limit: Int? {
        switch self {
        case .smoke5:
            return 5
        case .smoke20:
            return 20
        case .full:
            return nil
        }
    }
}

enum AIEvaluationRunnerError: LocalizedError {
    case datasetMissing
    case datasetUnreadable
    case datasetDecodeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .datasetMissing:
            return "The bundled AI evaluation dataset could not be found."
        case .datasetUnreadable:
            return "The bundled AI evaluation dataset could not be read."
        case .datasetDecodeFailed(let error):
            return "The bundled AI evaluation dataset could not be decoded: \(error.localizedDescription)"
        }
    }
}

@MainActor
@Observable
final class AIEvaluationRunner {
    private(set) var isRunning = false
    private(set) var processedCount = 0
    private(set) var totalCount = 0
    private(set) var currentCaseDescription: String?
    private(set) var report: AIEvaluationReport?
    private(set) var lastErrorMessage: String?
    private(set) var exportedPredictionsPath: String?
    private(set) var completedAt: Date?

    func run(size: AIEvaluationRunSize) async {
        reset()
        isRunning = true

        do {
            let allCases = try loadCases()
            let cases = Array(allCases.prefix(size.limit ?? allCases.count))
            totalCount = cases.count

            var predictions: [AIEvaluationPrediction] = []
            predictions.reserveCapacity(cases.count)
            var failures: [AIEvaluationFailure] = []

            for (index, evaluationCase) in cases.enumerated() {
                try Task.checkCancellation()

                processedCount = index
                currentCaseDescription = "\(evaluationCase.id) • \(evaluationCase.term)"

                do {
                    let result = try await AnswerGradingService.grade(
                        recalledText: evaluationCase.recalledText,
                        term: evaluationCase.term,
                        note: evaluationCase.note,
                        keyFacts: evaluationCase.keyFacts,
                        acceptedSynonyms: evaluationCase.acceptedSynonyms,
                        commonConfusions: evaluationCase.commonConfusions,
                        collectionName: evaluationCase.domain
                    )

                    predictions.append(
                        AIEvaluationPrediction(
                            id: evaluationCase.id,
                            suggestedRating: result.suggestedRating.rawValue,
                            primaryFeedbackCategory: result.primaryFeedbackCategory.rawValue,
                            secondaryFeedbackCategory: result.secondaryFeedbackCategory?.rawValue
                        )
                    )
                    processedCount = index + 1
                } catch {
                    failures.append(
                        AIEvaluationFailure(
                            id: evaluationCase.id,
                            domain: evaluationCase.domain,
                            term: evaluationCase.term,
                            errorDescription: error.localizedDescription
                        )
                    )
                    processedCount = index + 1
                }
            }

            exportedPredictionsPath = try writePredictions(predictions)
            report = Self.makeReport(cases: cases, predictions: predictions, failures: failures)
            if failures.isEmpty {
                lastErrorMessage = "Benchmark completed."
            } else {
                lastErrorMessage = "Benchmark completed with \(failures.count) case failures."
            }
            completedAt = Date()
        } catch is CancellationError {
            lastErrorMessage = "Benchmark cancelled."
            completedAt = Date()
        } catch {
            lastErrorMessage = error.localizedDescription
            completedAt = Date()
        }

        currentCaseDescription = nil
        isRunning = false
    }

    private func reset() {
        processedCount = 0
        totalCount = 0
        currentCaseDescription = nil
        report = nil
        lastErrorMessage = nil
        exportedPredictionsPath = nil
        completedAt = nil
    }

    private func loadCases() throws -> [AIEvaluationCase] {
        guard let url = Bundle.main.url(forResource: "ai-grading-eval-dataset", withExtension: "json") else {
            throw AIEvaluationRunnerError.datasetMissing
        }

        guard let data = FileManager.default.contents(atPath: url.path) else {
            throw AIEvaluationRunnerError.datasetUnreadable
        }

        do {
            return try JSONDecoder().decode([AIEvaluationCase].self, from: data)
        } catch {
            throw AIEvaluationRunnerError.datasetDecodeFailed(error)
        }
    }

    private func writePredictions(_ predictions: [AIEvaluationPrediction]) throws -> String {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-grading-live-predictions")
            .appendingPathExtension("json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(predictions)
        try data.write(to: outputURL, options: .atomic)
        return outputURL.path
    }

    private static func makeReport(
        cases: [AIEvaluationCase],
        predictions: [AIEvaluationPrediction],
        failures: [AIEvaluationFailure]
    ) -> AIEvaluationReport {
        let predictionMap = Dictionary(uniqueKeysWithValues: predictions.map { ($0.id, $0) })

        var matchedCount = 0
        var ratingCorrectCount = 0
        var falseEasyCount = 0
        var falseForgotCount = 0
        var easyOpportunities = 0
        var forgotOpportunities = 0
        var primaryFeedbackMatches = 0
        var primaryFeedbackEvaluated = 0
        var domainTallies: [String: (correct: Int, total: Int)] = [:]
        var confusionMatrix: [String: [String: Int]] = [:]
        var mismatches: [AIEvaluationMismatch] = []

        for evaluationCase in cases {
            guard let prediction = predictionMap[evaluationCase.id] else {
                continue
            }

            matchedCount += 1

            let expectedRating = evaluationCase.expectedRating
            let predictedRating = prediction.suggestedRating
            let ratingCorrect = expectedRating == predictedRating

            if ratingCorrect {
                ratingCorrectCount += 1
            } else {
                mismatches.append(
                    AIEvaluationMismatch(
                        id: evaluationCase.id,
                        domain: evaluationCase.domain,
                        term: evaluationCase.term,
                        expectedRating: expectedRating,
                        predictedRating: predictedRating,
                        expectedPrimaryFeedbackCategory: evaluationCase.expectedPrimaryFeedbackCategory,
                        predictedPrimaryFeedbackCategory: prediction.primaryFeedbackCategory
                    )
                )
            }

            if expectedRating != Rating.easy.rawValue {
                easyOpportunities += 1
                if predictedRating == Rating.easy.rawValue {
                    falseEasyCount += 1
                }
            }

            if expectedRating != Rating.forgot.rawValue {
                forgotOpportunities += 1
                if predictedRating == Rating.forgot.rawValue {
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

            let tally = domainTallies[evaluationCase.domain, default: (correct: 0, total: 0)]
            domainTallies[evaluationCase.domain] = (
                correct: tally.correct + (ratingCorrect ? 1 : 0),
                total: tally.total + 1
            )
        }

        let domainSummaries = domainTallies
            .map { domain, tally in
                AIEvaluationDomainSummary(domain: domain, correct: tally.correct, total: tally.total)
            }
            .sorted { $0.domain < $1.domain }

        let orderedRatings = [Rating.forgot.rawValue, Rating.hard.rawValue, Rating.easy.rawValue]
        let confusionRows = orderedRatings.map { expectedRating in
            AIEvaluationConfusionRow(
                expectedRating: expectedRating,
                forgotCount: confusionMatrix[expectedRating]?[Rating.forgot.rawValue] ?? 0,
                hardCount: confusionMatrix[expectedRating]?[Rating.hard.rawValue] ?? 0,
                easyCount: confusionMatrix[expectedRating]?[Rating.easy.rawValue] ?? 0
            )
        }

        return AIEvaluationReport(
            datasetCaseCount: cases.count,
            predictionsProvided: predictions.count,
            matchedCount: matchedCount,
            ratingCorrectCount: ratingCorrectCount,
            falseEasyCount: falseEasyCount,
            easyOpportunities: easyOpportunities,
            falseForgotCount: falseForgotCount,
            forgotOpportunities: forgotOpportunities,
            primaryFeedbackMatches: primaryFeedbackMatches,
            primaryFeedbackEvaluated: primaryFeedbackEvaluated,
            failures: failures,
            mismatches: mismatches,
            domainSummaries: domainSummaries,
            confusionRows: confusionRows
        )
    }
}

private func rate(numerator: Int, denominator: Int) -> Double {
    guard denominator > 0 else { return 0 }
    return Double(numerator) / Double(denominator)
}
#endif
