import Foundation

enum ReviewCadence: String, CaseIterable, Identifiable {
    case standard
    case relaxed
    case intensive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "Standard"
        case .relaxed: return "Relaxed"
        case .intensive: return "Intensive"
        }
    }

    var description: String {
        switch self {
        case .standard: return "Adaptive intervals: 1d → 6d → 17d+, mastery at 21 days"
        case .relaxed: return "Longer intervals: 2d → 9d → grows, mastery at 28 days"
        case .intensive: return "Shorter intervals: 1d → 4d → grows, mastery at 14 days"
        }
    }
}

enum AppSettings {
    static let reviewReminderEnabledKey = "reviewReminderEnabled"
    static let reviewReminderHourKey = "reviewReminderHour"
    static let reviewReminderMinuteKey = "reviewReminderMinute"
    static let reviewCadenceKey = "reviewCadence"

    static var currentCadence: ReviewCadence {
        let rawValue = UserDefaults.standard.string(forKey: reviewCadenceKey) ?? ReviewCadence.standard.rawValue
        return ReviewCadence(rawValue: rawValue) ?? .standard
    }
}
