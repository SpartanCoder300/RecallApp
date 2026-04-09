import Foundation

/// Plain-data input to the scheduling engine.
/// Decoupled from SwiftData so the engine stays a pure, side-effect-free function.
struct ReviewRecord {
    let reviewedAt: Date
    let rating: Rating
}

/// Determines when a recall item should next be reviewed using the SM-2 algorithm.
///
/// SM-2 grows intervals exponentially with each successful review:
///   - 1st Easy → 1 day
///   - 2nd Easy → 6 days
///   - 3rd Easy → ~17 days
///   - 4th Easy → ~49 days (mastered)
///
/// Hard is a weak pass: interval grows at 1.2× instead of the full ease factor,
/// and the repetition counter is not incremented.
/// Forgot resets progress: interval returns to 1 day and repetitions reset to 0.
///
/// All methods are pure functions — given the same input they always return the same output.
enum SchedulingEngine {

    // MARK: - Public API

    /// Returns the next due date for an item given its full review history.
    ///
    /// - Returns: `Date.distantPast` when `records` is empty, meaning the item is
    ///   immediately due (it has never been reviewed). Otherwise returns the date of
    ///   the most recent review plus the SM-2 computed interval.
    static func nextDueDate(
        after records: [ReviewRecord],
        cadence: ReviewCadence = .standard
    ) -> Date {
        guard !records.isEmpty else { return .distantPast }
        let sorted = records.sorted { $0.reviewedAt < $1.reviewedAt }
        let state = computeState(from: sorted, cadence: cadence)
        let intervalSeconds = Double(state.interval) * 86_400
        return sorted[sorted.count - 1].reviewedAt.addingTimeInterval(intervalSeconds)
    }

    /// Returns whether an item's SM-2 interval has reached the mastery threshold for the given cadence.
    ///
    /// Thresholds: Standard → 21 days, Relaxed → 28 days, Intensive → 14 days.
    static func isMastered(
        after records: [ReviewRecord],
        cadence: ReviewCadence = .standard
    ) -> Bool {
        guard !records.isEmpty else { return false }
        let sorted = records.sorted { $0.reviewedAt < $1.reviewedAt }
        let state = computeState(from: sorted, cadence: cadence)
        return state.interval >= masteryThreshold(for: cadence)
    }

    // MARK: - SM-2 Core

    private struct SM2State {
        /// Ease multiplier. Starts at 2.5, decreases with Hard/Forgot, increases with Easy.
        var easeFactor: Double = 2.5
        /// Current scheduled interval in days.
        var interval: Int = 0
        /// Count of consecutive successful (non-Forgot) review passes. Hard does not increment this.
        var repetitions: Int = 0
    }

    private static func computeState(from sortedRecords: [ReviewRecord], cadence: ReviewCadence) -> SM2State {
        var state = SM2State()
        for record in sortedRecords {
            apply(record.rating, to: &state, cadence: cadence)
        }
        return state
    }

    private static func apply(_ rating: Rating, to state: inout SM2State, cadence: ReviewCadence) {
        switch rating {
        case .missed:
            // Failed review: reset progress and decrease ease.
            state.easeFactor = max(1.3, state.easeFactor - 0.2)
            state.repetitions = 0
            state.interval = baseInterval(cadence: cadence)

        case .partial:
            // Weak pass: interval grows slowly (×1.2), ease decreases, repetitions unchanged.
            state.easeFactor = max(1.3, state.easeFactor - 0.15)
            if state.interval == 0 {
                state.interval = baseInterval(cadence: cadence)
            } else {
                let grown = Int((Double(state.interval) * 1.2).rounded())
                // Always advance by at least 1 day so interval is strictly increasing.
                state.interval = max(state.interval + 1, grown)
            }

        case .nailed:
            // Full pass: interval grows by ease factor, ease increases, repetitions increment.
            state.easeFactor += 0.1
            switch state.repetitions {
            case 0:
                state.interval = baseInterval(cadence: cadence)
            case 1:
                state.interval = secondInterval(cadence: cadence)
            default:
                let grown = Int((Double(state.interval) * state.easeFactor).rounded())
                state.interval = max(state.interval + 1, grown)
            }
            state.repetitions += 1
        }
    }

    // MARK: - Cadence-based constants

    /// The interval assigned after a first-review or a Forgot reset.
    private static func baseInterval(cadence: ReviewCadence) -> Int {
        switch cadence {
        case .standard, .intensive: return 1
        case .relaxed: return 2
        }
    }

    /// The interval assigned after the second consecutive Easy review (rep 1 → 2).
    private static func secondInterval(cadence: ReviewCadence) -> Int {
        switch cadence {
        case .standard: return 6
        case .relaxed: return 9
        case .intensive: return 4
        }
    }

    /// The interval (in days) at which a card is considered mastered.
    private static func masteryThreshold(for cadence: ReviewCadence) -> Int {
        switch cadence {
        case .standard: return 21
        case .relaxed: return 28
        case .intensive: return 14
        }
    }
}
