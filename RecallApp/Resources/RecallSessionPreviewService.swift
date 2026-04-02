import SwiftUI

struct RecallSessionPreviewConfiguration {
    let queue: [RecallItem]
    let completedCount: Int
    let results: [SessionResult]
    let recalledText: String
    let revealedNote: String?
    let hintText: String?
    let gradingState: GradingState
    let focusRecallField: Bool
}

enum RecallSessionPreviewService {
    static let sessionItems: [RecallItem] = [
        PreviewService.itemWithNote,
        PreviewService.itemWithoutNote
    ]

    static let sessionCompleteResults: [SessionResult] = [
        SessionResult(item: PreviewService.itemWithNote, rating: .easy),
        SessionResult(item: PreviewService.itemWithoutNote, rating: .hard)
    ]

    static let aiResponseItem = RecallItem(
        term: "MQTT QoS 0",
        note: "At most once delivery. Messages are sent once with no acknowledgment or retry."
    )

    static let aiResponseText = "Send and forget"

    static let aiResponseResult = GradingResult(
        suggestedRating: .hard,
        reasoning: "You got the main idea but missed that delivery is at most once with no acknowledgment or retry.",
        primaryFeedbackCategory: .importantQualifierMissing,
        secondaryFeedbackCategory: .mainIdeaCaptured,
        coreIdeaCorrect: true,
        missingConcepts: "No acknowledgment or retry",
        incorrectClaims: nil,
        confidence: .high,
        shouldResurfaceSoon: true
    )

    static let liveSessionConfiguration = RecallSessionPreviewConfiguration(
        queue: sessionItems,
        completedCount: 0,
        results: [],
        recalledText: "",
        revealedNote: nil,
        hintText: nil,
        gradingState: .idle,
        focusRecallField: false
    )

    static let aiResponseConfiguration = RecallSessionPreviewConfiguration(
        queue: [aiResponseItem, PreviewService.itemWithoutNote],
        completedCount: 0,
        results: [],
        recalledText: aiResponseText,
        revealedNote: nil,
        hintText: nil,
        gradingState: .result(aiResponseResult),
        focusRecallField: false
    )

    static let sessionCompleteConfiguration = RecallSessionPreviewConfiguration(
        queue: [],
        completedCount: sessionCompleteResults.count,
        results: sessionCompleteResults,
        recalledText: "",
        revealedNote: nil,
        hintText: nil,
        gradingState: .idle,
        focusRecallField: false
    )
}
