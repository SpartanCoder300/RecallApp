import SwiftUI
import SwiftData

// MARK: - Color palette

/// A fixed set of adaptive system colors for collection labelling.
/// Stored as a raw String so SwiftData can persist it without custom transformers.
enum CollectionColor: String, Codable, CaseIterable {
    case blue   = "blue"
    case purple = "purple"
    case green  = "green"
    case orange = "orange"
    case pink   = "pink"
    case teal   = "teal"
    case indigo = "indigo"
    case red    = "red"

    var color: Color {
        switch self {
        case .blue:   return Color(.systemBlue)
        case .purple: return Color(.systemPurple)
        case .green:  return Color(.systemGreen)
        case .orange: return Color(.systemOrange)
        case .pink:   return Color(.systemPink)
        case .teal:   return Color(.systemTeal)
        case .indigo: return Color(.systemIndigo)
        case .red:    return Color(.systemRed)
        }
    }
}

// MARK: - Model

/// A named group of RecallItems. Used to scope review sessions to a topic or context.
/// Items are never required to belong to a collection — the field is always optional.
@Model
final class RecallCollection {
    var id: UUID
    var name: String
    var colorValue: CollectionColor
    var createdAt: Date

    /// When a collection is deleted its items are kept — their collection reference is nullified.
    @Relationship(deleteRule: .nullify, inverse: \RecallItem.collection)
    var items: [RecallItem] = []

    init(name: String, color: CollectionColor = .blue) {
        self.id = UUID()
        self.name = name
        self.colorValue = color
        self.createdAt = Date()
    }
}
