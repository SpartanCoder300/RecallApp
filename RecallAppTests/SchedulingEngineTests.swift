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

    /// Computes the interval in whole days between the last review and nextDueDate.
    private func computedInterval(after records: [ReviewRecord], cadence: ReviewCadence = .standard) -> Int {
        guard let last = records.max(by: { $0.reviewedAt < $1.reviewedAt }) else { return 0 }
        let due = SchedulingEngine.nextDueDate(after: records, cadence: cadence)
        return Int((due.timeIntervalSince(last.reviewedAt) / 86_400).rounded())
    }

    // MARK: - Zero reviews

    func test_noReviews_returnsDistantPast() {
        XCTAssertEqual(SchedulingEngine.nextDueDate(after: []), .distantPast)
    }

    func test_noReviews_notMastered() {
        XCTAssertFalse(SchedulingEngine.isMastered(after: []))
    }

    // MARK: - First review (bootstrap intervals)

    func test_firstNailed_schedules1Day() {
        XCTAssertEqual(computedInterval(after: [record(.nailed)]), 1)
    }

    func test_firstPartial_schedules1Day() {
        XCTAssertEqual(computedInterval(after: [record(.partial)]), 1)
    }

    func test_firstMissed_schedules1Day() {
        XCTAssertEqual(computedInterval(after: [record(.missed)]), 1)
    }

    // MARK: - Second review

    func test_twoNailed_schedules6Days() {
        let records = [record(.nailed, daysAgo: 2), record(.nailed, daysAgo: 1)]
        XCTAssertEqual(computedInterval(after: records), 6)
    }

    func test_nailedThenMissed_resetsTo1Day() {
        let records = [record(.nailed, daysAgo: 2), record(.missed, daysAgo: 1)]
        XCTAssertEqual(computedInterval(after: records), 1)
    }

    func test_nailedThenPartial_growsSlowly() {
        // After Easy (interval=1), Hard → interval = max(1+1, round(1×1.2)) = max(2, 1) = 2
        let records = [record(.nailed, daysAgo: 2), record(.partial, daysAgo: 1)]
        XCTAssertEqual(computedInterval(after: records), 2)
    }

    // MARK: - Exponential growth (3+ reviews)

    func test_threeNailed_growsExponentially() {
        // rep0→easy: interval=1, ef=2.6
        // rep1→easy: interval=6, ef=2.7
        // rep2→easy: interval=round(6×2.8)=17, ef=2.8  (ef updated first, then used)
        let records = [
            record(.nailed, daysAgo: 15),
            record(.nailed, daysAgo: 8),
            record(.nailed, daysAgo: 1)
        ]
        XCTAssertEqual(computedInterval(after: records), 17)
    }

    func test_fourNailed_intervalsAreLarge() {
        // After 3 Easy: interval=17, ef=2.8
        // 4th Easy: ef=2.9, interval=round(17×2.9)=49
        let records = [
            record(.nailed, daysAgo: 50),
            record(.nailed, daysAgo: 32),
            record(.nailed, daysAgo: 15),
            record(.nailed, daysAgo: 1)
        ]
        XCTAssertEqual(computedInterval(after: records), 49)
    }

    // MARK: - Forgot resets

    func test_missedAfterThreeNailed_resetsTo1Day() {
        let records = [
            record(.nailed, daysAgo: 25),
            record(.nailed, daysAgo: 18),
            record(.nailed, daysAgo: 10),
            record(.missed, daysAgo: 1)
        ]
        XCTAssertEqual(computedInterval(after: records), 1)
    }

    func test_nailedAfterMissed_restartsBootstrap() {
        // Forgot resets rep to 0; next Easy → rep 0→1, interval = 1
        let records = [
            record(.nailed, daysAgo: 8),
            record(.nailed, daysAgo: 2),
            record(.missed, daysAgo: 1),
        ]
        // Next would be Easy → interval = 1 (bootstrap restart)
        // But we're testing the Forgot state: interval = 1
        XCTAssertEqual(computedInterval(after: records), 1)
    }

    // MARK: - Hard behaviour

    func test_partialNeverDecrementsRepetitions() {
        // Easy×2 sets rep=2, then Hard → rep stays 2
        // Subsequent Easy should use rep=2 path (interval grows by easeFactor, not bootstrap)
        let afterEasyEasy = [record(.nailed, daysAgo: 10), record(.nailed, daysAgo: 4)]
        let afterEasyEasyHard = afterEasyEasy + [record(.partial, daysAgo: 2)]
        let afterEasyEasyHardEasy = afterEasyEasyHard + [record(.nailed, daysAgo: 1)]

        // After Easy,Easy: interval=6, ef=2.7, rep=2
        // After Hard: ef=2.55, interval=max(7, round(6×1.2))=max(7,7)=7, rep=2
        // After Easy: ef=2.65, interval=round(7×2.65)=19, rep=3
        XCTAssertEqual(computedInterval(after: afterEasyEasyHard), 7)
        XCTAssertEqual(computedInterval(after: afterEasyEasyHardEasy), 19)
    }

    func test_partialAlwaysIncreasesInterval() {
        // Even with a very short interval, Hard must produce a strictly larger interval.
        let records = [record(.nailed, daysAgo: 2), record(.partial, daysAgo: 1)]
        let interval = computedInterval(after: records)
        XCTAssertGreaterThan(interval, 1) // must grow beyond the Easy bootstrap of 1
    }

    // MARK: - Input order independence

    func test_outOfOrderInput_producesCorrectResult() {
        // Shuffled input should produce the same result as sorted input.
        let day1 = Date().addingTimeInterval(-10 * 86_400)
        let day2 = Date().addingTimeInterval(-4  * 86_400)
        let day3 = Date().addingTimeInterval(-1  * 86_400)

        let sorted: [ReviewRecord] = [
            ReviewRecord(reviewedAt: day1, rating: .nailed),
            ReviewRecord(reviewedAt: day2, rating: .nailed),
            ReviewRecord(reviewedAt: day3, rating: .nailed),
        ]
        let shuffled: [ReviewRecord] = [
            ReviewRecord(reviewedAt: day3, rating: .nailed),
            ReviewRecord(reviewedAt: day1, rating: .nailed),
            ReviewRecord(reviewedAt: day2, rating: .nailed),
        ]

        XCTAssertEqual(
            SchedulingEngine.nextDueDate(after: sorted),
            SchedulingEngine.nextDueDate(after: shuffled)
        )
    }

    // MARK: - Cadence

    func test_relaxedCadence_firstEasySchedules2Days() {
        XCTAssertEqual(computedInterval(after: [record(.nailed)], cadence: .relaxed), 2)
    }

    func test_relaxedCadence_twoEasySchedules9Days() {
        let records = [record(.nailed, daysAgo: 3), record(.nailed, daysAgo: 1)]
        XCTAssertEqual(computedInterval(after: records, cadence: .relaxed), 9)
    }

    func test_intensiveCadence_twoEasySchedules4Days() {
        let records = [record(.nailed, daysAgo: 2), record(.nailed, daysAgo: 1)]
        XCTAssertEqual(computedInterval(after: records, cadence: .intensive), 4)
    }

    // MARK: - Mastery

    func test_threeNailed_notMastered() {
        // 3 Easy reviews → interval=17, threshold=21 for standard
        let records = [
            record(.nailed, daysAgo: 24),
            record(.nailed, daysAgo: 17),
            record(.nailed, daysAgo: 1)
        ]
        XCTAssertFalse(SchedulingEngine.isMastered(after: records))
    }

    func test_fourNailed_mastered() {
        // 4 Easy reviews → interval=49, threshold=21 for standard
        let records = [
            record(.nailed, daysAgo: 58),
            record(.nailed, daysAgo: 40),
            record(.nailed, daysAgo: 23),
            record(.nailed, daysAgo: 1)
        ]
        XCTAssertTrue(SchedulingEngine.isMastered(after: records))
    }

    func test_masteredCardThenMissed_notMastered() {
        // A mastered card that gets Forgot is no longer mastered.
        let records = [
            record(.nailed, daysAgo: 60),
            record(.nailed, daysAgo: 42),
            record(.nailed, daysAgo: 25),
            record(.nailed, daysAgo: 8),
            record(.missed, daysAgo: 1)
        ]
        XCTAssertFalse(SchedulingEngine.isMastered(after: records))
    }

    func test_intensiveMastery_lowerThreshold() {
        // Intensive mastery threshold is 14 days.
        // After 3 Easy reviews (interval=17 days), already mastered under intensive.
        let records = [
            record(.nailed, daysAgo: 12),
            record(.nailed, daysAgo: 6),
            record(.nailed, daysAgo: 1)
        ]
        XCTAssertTrue(SchedulingEngine.isMastered(after: records, cadence: .intensive))
        XCTAssertFalse(SchedulingEngine.isMastered(after: records, cadence: .standard))
    }
}
