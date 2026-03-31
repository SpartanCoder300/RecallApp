import Foundation

/// Plain-data input to the scheduling engine.
/// Decoupled from SwiftData so the engine stays a pure, side-effect-free function.
struct ReviewRecord {
    let reviewedAt: Date
    let rating: Rating
}

/// Determines when a recall item should next be reviewed.
/// All methods are pure functions — given the same input they always return the same output.
enum SchedulingEngine {

    /// Returns the next due date for an item given its full review history.
    ///
    /// - Returns: `Date.distantPast` when `records` is empty, meaning the item is
    ///   immediately due (it has never been reviewed). Otherwise returns the date of
    ///   the most recent review plus the interval for that review's rating.
    static func nextDueDate(
        after records: [ReviewRecord],
        cadence: ReviewCadence = .standard
    ) -> Date {
        guard let last = records.max(by: { $0.reviewedAt < $1.reviewedAt }) else {
            return .distantPast
        }
        let interval = interval(for: last.rating, cadence: cadence)
        return last.reviewedAt.addingTimeInterval(interval)
    }

    private static func interval(for rating: Rating, cadence: ReviewCadence) -> TimeInterval {
        switch cadence {
        case .standard:
            switch rating {
            case .forgot: return 1 * 86_400
            case .hard: return 3 * 86_400
            case .easy: return 7 * 86_400
            }
        case .relaxed:
            switch rating {
            case .forgot: return 2 * 86_400
            case .hard: return 5 * 86_400
            case .easy: return 10 * 86_400
            }
        case .intensive:
            switch rating {
            case .forgot: return 1 * 86_400
            case .hard: return 2 * 86_400
            case .easy: return 5 * 86_400
            }
        }
    }
}
