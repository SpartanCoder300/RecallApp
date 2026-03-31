import UIKit

/// Centralised haptic feedback. All UIKit types are internal — callers need no UIKit import.
enum HapticManager {

    // MARK: - Impact (physical tap sensation)

    /// Subtle: list selection, minor state changes.
    static func soft()   { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    /// Default for most button taps and card advances.
    static func light()  { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    /// Used for primary confirmations (e.g. + button press).
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    /// Reserved for high-emphasis moments only.
    static func heavy()  { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }

    // MARK: - Notification (outcome feedback)

    /// Save confirmed, review session complete.
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    /// Potentially destructive action, soft warning.
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    /// Invalid action, empty-save attempt.
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }

    // MARK: - Selection (discrete value change)

    /// Rating button tap, picker step change.
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}
