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

    // Fixed-interval table (V1). SM-2 algorithm replaces this in V2.
    private static let intervals: [Rating: TimeInterval] = [
        .forgot: 1 * 86_400,   // 1 day
        .hard:   3 * 86_400,   // 3 days
        .easy:   7 * 86_400,   // 7 days
    ]

    /// Returns the next due date for an item given its full review history.
    ///
    /// - Returns: `Date.distantPast` when `records` is empty, meaning the item is
    ///   immediately due (it has never been reviewed). Otherwise returns the date of
    ///   the most recent review plus the interval for that review's rating.
    static func nextDueDate(after records: [ReviewRecord]) -> Date {
        guard let last = records.max(by: { $0.reviewedAt < $1.reviewedAt }) else {
            return .distantPast
        }
        let interval = intervals[last.rating] ?? 86_400
        return last.reviewedAt.addingTimeInterval(interval)
    }
}
