import UIKit

/// Centralised haptic feedback. Call these from views — never instantiate
/// UIImpactFeedbackGenerator directly elsewhere in the codebase.
enum HapticManager {

    /// Standard impact — use for taps, button presses, card advances.
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    /// Notification feedback — use for save confirmation, review complete, errors.
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    /// Selection feedback — use for picker changes, rating taps.
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
