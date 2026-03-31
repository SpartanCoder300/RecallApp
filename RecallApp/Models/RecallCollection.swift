import SwiftUI
import SwiftData

// MARK: - Color palette

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

@Model
final class RecallCollection {
    var id: UUID = UUID()
    var name: String = ""
    /// Stored as a raw String — SwiftData cannot reliably persist custom Codable
    /// enums as stored properties on device. Access via the `color` computed property.
    var colorName: String = CollectionColor.blue.rawValue
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \RecallItem.collection)
    var items: [RecallItem]?

    /// Typed access to the stored color value.
    var color: CollectionColor {
        CollectionColor(rawValue: colorName) ?? .blue
    }

    init(name: String, color: CollectionColor = .blue) {
        self.id = UUID()
        self.name = name
        self.colorName = color.rawValue
        self.createdAt = Date()
    }
}
