# Agent Guidelines — RecallApp

## Platform Target
- **Minimum deployment target: iOS 26.1+**
- Never add `@available` guards or fallbacks for APIs already available in iOS 26.1.
- Never write code paths intended for older OS versions.

## Human Interface Guidelines (Non-Negotiable)
All UI work must conform to [Apple's Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/).

### Native Controls First
Before writing any custom UI, check whether a native SwiftUI control solves the problem. Examples:

| Need | Use |
|------|-----|
| Lists / tables | `List` |
| Navigation | `NavigationStack` |
| Tab switching | `TabView` |
| Modals / drawers | `.sheet`, `.fullScreenCover` |
| Toggles | `Toggle` |
| Pickers | `Picker` with appropriate style |
| Buttons | `Button` with a system role or style |
| Menus | `Menu` |
| Alerts / confirmations | `.alert`, `.confirmationDialog` |
| Search | `.searchable` |

Custom controls are only permitted when a native equivalent **cannot** meet the requirement. Any custom control must include a comment: `// Custom: native [ControlName] cannot [reason].`

### Typography
- Use Dynamic Type text styles exclusively: `.largeTitle`, `.title`, `.headline`, `.body`, `.callout`, `.subheadline`, `.footnote`, `.caption`.
- Never hardcode font sizes (no `Font.system(size: 14)`).

### Color
- Use semantic system colors: `Color.primary`, `Color.secondary`, `Color.accentColor`, `Color(.systemBackground)`, etc.
- Dark Mode and high-contrast support must work automatically — no hardcoded hex colors.

### Iconography
- Use SF Symbols for all icons (`Image(systemName:)`).
- Do not add custom icon assets for concepts SF Symbols already covers.

### Spacing & Layout
- Use system spacing values and `.padding()` defaults. Avoid arbitrary magic numbers.
- Respect safe area insets — never force content under system chrome.

### Accessibility
- Every interactive control must have a meaningful `.accessibilityLabel`.
- Use `.accessibilityHint` to describe actions where the label alone is ambiguous.
- Use `.accessibilityAddTraits` to correctly identify roles (e.g., `.isButton`, `.isHeader`).
- Do not disable or suppress accessibility features.

### Animations
- Use SwiftUI system animations and transitions.
- Custom timing curves require explicit justification in a code comment.

## Code Conventions
- Swift only — no Objective-C.
- Use `@Observable` (Swift Observation) over `ObservableObject` / `@StateObject`.
- Use `NavigationStack` — not `NavigationView`.
- Use `#Preview` macros for all SwiftUI previews.
- Previews must not depend on SwiftData stores or `.modelContainer(...)` setup for sample content.
- Build previews from injected sample models/snapshots via a dedicated preview service or preview wrapper views.
- Keep runtime data loading and preview data generation separate so previews remain deterministic and do not crash on container initialization.
- No third-party dependencies without explicit approval.
- No deprecated APIs.
