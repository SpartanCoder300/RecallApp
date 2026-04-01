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
        case .standard: return "Forgot -> 1d, Hard -> 3d, Easy -> 7d"
        case .relaxed: return "Longer gaps between reviews"
        case .intensive: return "Shorter gaps between reviews"
        }
    }
}

enum AppSettings {
    static let reviewReminderEnabledKey = "reviewReminderEnabled"
    static let reviewReminderHourKey = "reviewReminderHour"
    static let reviewReminderMinuteKey = "reviewReminderMinute"
    static let reviewCadenceKey = "reviewCadence"

    // Pro
    static let isProUserKey = "isProUser"
    static let aiGradingEnabledKey = "aiGradingEnabled"

    static var currentCadence: ReviewCadence {
        let rawValue = UserDefaults.standard.string(forKey: reviewCadenceKey) ?? ReviewCadence.standard.rawValue
        return ReviewCadence(rawValue: rawValue) ?? .standard
    }

    static var isProUser: Bool {
        UserDefaults.standard.bool(forKey: isProUserKey)
    }
}
