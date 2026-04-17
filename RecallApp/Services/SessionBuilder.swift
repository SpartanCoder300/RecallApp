import Foundation

/// Builds a prioritized review queue that prevents daily overload.
///
/// Two rules keep the workload manageable:
///  1. **Due reviews** (reviewed before, now past their due date) always appear — the user
///     already committed to these and skipping them compounds debt.
///  2. **New cards** (never reviewed) are capped at `dailyNewLimit` minus however many
///     new cards were already introduced today, so fresh items drip in gradually rather
///     than flooding in all at once.
///
/// New cards are ordered oldest-first so the user works through them in the order they
/// were added. Due reviews are returned unsorted — the session screen can shuffle them.
enum SessionBuilder {

    static func buildQueue(
        from allItems: [RecallItem],
        dailyNewLimit: Int,
        now: Date = Date()
    ) -> [RecallItem] {
        let calendar = Calendar.current

        let dueReviews = allItems.filter { item in
            let reviews = item.reviews ?? []
            return !reviews.isEmpty && item.isDue
        }

        let neverReviewed = allItems
            .filter { ($0.reviews ?? []).isEmpty }
            .sorted { $0.createdAt < $1.createdAt }

        // New cards the user already saw for the first time today don't count against
        // tomorrow's limit — they count against today's, so we respect the daily cap
        // even mid-session.
        let introducedToday = allItems.filter { item in
            let reviews = item.reviews ?? []
            guard reviews.count == 1 else { return false }
            return calendar.isDateInToday(reviews[0].reviewedAt)
        }.count

        let newSlots = max(0, dailyNewLimit - introducedToday)
        let newForSession = Array(neverReviewed.prefix(newSlots))

        return dueReviews + newForSession
    }

    /// Returns the daily new-card limit appropriate for the given cadence.
    static func dailyNewLimit(for cadence: ReviewCadence) -> Int {
        switch cadence {
        case .relaxed:   return 5
        case .standard:  return 10
        case .intensive: return 20
        }
    }
}
