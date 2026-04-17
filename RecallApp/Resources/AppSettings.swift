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
        case .standard: return "Reviews grow further apart as you remember more. A balanced default for most learners."
        case .relaxed:  return "Longer gaps between reviews. Good if you prefer a lighter daily load."
        case .intensive: return "Shorter gaps and a lower mastery bar. Best for fast-paced exam preparation."
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
