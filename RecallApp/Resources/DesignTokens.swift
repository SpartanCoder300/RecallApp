// DesignTokens.swift — Single source of truth for all design values.
// Every view must reference these tokens. Nothing is hardcoded in individual views.

import SwiftUI
import UIKit

/// Top-level namespace. Use `DT.Color.background`, `DT.Spacing.md`, etc.
enum DT {

    // MARK: - Color
    enum Color {
        // Backgrounds — adapts automatically to light/dark mode
        static let background:      SwiftUI.Color = SwiftUI.Color(UIColor.systemBackground)
        static let surface:         SwiftUI.Color = SwiftUI.Color(UIColor.secondarySystemBackground)
        static let surfaceElevated: SwiftUI.Color = SwiftUI.Color(UIColor.tertiarySystemBackground)

        // Text
        static let textPrimary:   SwiftUI.Color = SwiftUI.Color(UIColor.label)
        static let textSecondary: SwiftUI.Color = SwiftUI.Color(UIColor.secondaryLabel)
        static let textTertiary:  SwiftUI.Color = SwiftUI.Color(UIColor.tertiaryLabel)

        // Accent & semantic
        static let accent:      SwiftUI.Color = .accentColor
        static let destructive: SwiftUI.Color = SwiftUI.Color(UIColor.systemRed)
        static let success:     SwiftUI.Color = SwiftUI.Color(UIColor.systemGreen)
        static let separator:   SwiftUI.Color = SwiftUI.Color(UIColor.separator)

        // Fill
        static let fill:          SwiftUI.Color = SwiftUI.Color(UIColor.systemFill)
        static let fillSecondary: SwiftUI.Color = SwiftUI.Color(UIColor.secondarySystemFill)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    enum Radius {
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let xl:   CGFloat = 24
        static let card: CGFloat = 20
    }

    // MARK: - Typography
    // All sizes use Dynamic Type — never pass a hardcoded point size to Font.
    enum Typography {
        static let largeTitle:  Font = .largeTitle
        static let title:       Font = .title
        static let title2:      Font = .title2
        static let title3:      Font = .title3
        static let headline:    Font = .headline
        static let body:        Font = .body
        static let callout:     Font = .callout
        static let subheadline: Font = .subheadline
        static let footnote:    Font = .footnote
        static let caption:     Font = .caption
        static let caption2:    Font = .caption2
    }
}
