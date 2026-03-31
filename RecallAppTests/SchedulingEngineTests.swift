import XCTest
@testable import RecallApp

final class SchedulingEngineTests: XCTestCase {

    // MARK: - Helpers

    private func record(_ rating: Rating, daysAgo: Double = 0) -> ReviewRecord {
        ReviewRecord(
            reviewedAt: Date().addingTimeInterval(-daysAgo * 86_400),
            rating: rating
        )
    }

    // MARK: - Zero reviews

    func test_noReviews_returnsDistantPast() {
        XCTAssertEqual(SchedulingEngine.nextDueDate(after: []), .distantPast)
    }

    // MARK: - Single review — every rating path

    func test_forgot_schedules1Day() {
        let reviewedAt = Date()
        let result = SchedulingEngine.nextDueDate(after: [
            ReviewRecord(reviewedAt: reviewedAt, rating: .forgot)
        ])
        XCTAssertEqual(result, reviewedAt.addingTimeInterval(1 * 86_400))
    }

    func test_hard_schedules3Days() {
        let reviewedAt = Date()
        let result = SchedulingEngine.nextDueDate(after: [
            ReviewRecord(reviewedAt: reviewedAt, rating: .hard)
        ])
        XCTAssertEqual(result, reviewedAt.addingTimeInterval(3 * 86_400))
    }

    func test_easy_schedules7Days() {
        let reviewedAt = Date()
        let result = SchedulingEngine.nextDueDate(after: [
            ReviewRecord(reviewedAt: reviewedAt, rating: .easy)
        ])
        XCTAssertEqual(result, reviewedAt.addingTimeInterval(7 * 86_400))
    }

    // MARK: - Multiple reviews — always uses the latest by date

    func test_multipleReviews_usesLatestByDate() {
        let earlier = Date().addingTimeInterval(-10 * 86_400)
        let later   = Date().addingTimeInterval(-2  * 86_400)

        let records = [
            ReviewRecord(reviewedAt: earlier, rating: .easy),   // would give day −10 + 7
            ReviewRecord(reviewedAt: later,   rating: .forgot), // should win: day −2 + 1
        ]

        XCTAssertEqual(
            SchedulingEngine.nextDueDate(after: records),
            later.addingTimeInterval(1 * 86_400)
        )
    }

    func test_multipleReviews_outOfOrderInput_stillUsesLatest() {
        let day1 = Date().addingTimeInterval(-5 * 86_400)
        let day2 = Date().addingTimeInterval(-3 * 86_400)
        let day3 = Date().addingTimeInterval(-1 * 86_400) // latest

        // Deliberately shuffled
        let records = [
            ReviewRecord(reviewedAt: day2, rating: .hard),
            ReviewRecord(reviewedAt: day3, rating: .easy),  // latest — must win
            ReviewRecord(reviewedAt: day1, rating: .forgot),
        ]

        XCTAssertEqual(
            SchedulingEngine.nextDueDate(after: records),
            day3.addingTimeInterval(7 * 86_400)
        )
    }

    // MARK: - Interval accuracy after rating changes

    func test_forgotAfterEasy_resetsTo1Day() {
        let first  = Date().addingTimeInterval(-8 * 86_400)
        let second = Date().addingTimeInterval(-1 * 86_400)

        let records = [
            ReviewRecord(reviewedAt: first,  rating: .easy),
            ReviewRecord(reviewedAt: second, rating: .forgot),
        ]

        XCTAssertEqual(
            SchedulingEngine.nextDueDate(after: records),
            second.addingTimeInterval(1 * 86_400)
        )
    }

    func test_easyAfterForgot_jumpsTo7Days() {
        let first  = Date().addingTimeInterval(-2 * 86_400)
        let second = Date().addingTimeInterval(-1 * 86_400)

        let records = [
            ReviewRecord(reviewedAt: first,  rating: .forgot),
            ReviewRecord(reviewedAt: second, rating: .easy),
        ]

        XCTAssertEqual(
            SchedulingEngine.nextDueDate(after: records),
            second.addingTimeInterval(7 * 86_400)
        )
    }
}
