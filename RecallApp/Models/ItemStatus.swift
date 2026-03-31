import Foundation

/// The human-readable state of a recall item at a given moment.
enum ItemStatus: Equatable {
    /// Never been reviewed.
    case new
    /// Past its due date — needs review now.
    case due
    /// Scheduled review is coming up in N days.
    case upcoming(days: Int)
    /// Reviewed 5+ times with the last rating being Easy.
    case mastered

    /// Short label for display in badges and lists.
    var label: String {
        switch self {
        case .new:                return "New"
        case .due:                return "Due"
        case .upcoming(let days): return "In \(days)d"
        case .mastered:           return "Mastered"
        }
    }
}
