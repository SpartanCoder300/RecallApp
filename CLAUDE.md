# Claude Code Guidelines — RecallApp

## Platform Target
- **Minimum deployment target: iOS 26.1+**
- Do not add availability checks or fallbacks for anything already available in iOS 26.1.
- Do not write code that supports older OS versions.

## Human Interface Guidelines
All UI work must follow [Apple's Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/). Key rules:

- **Native controls first.** Always use a native SwiftUI or UIKit control before reaching for a custom implementation. If `List`, `Button`, `Toggle`, `Picker`, `NavigationStack`, `TabView`, `Sheet`, etc. can do the job, use them.
- **No custom controls unless justified.** Custom UI components are only acceptable when the native equivalent genuinely cannot meet the requirement. If you write a custom control, leave a comment explaining why the native alternative was insufficient.
- **Typography.** Use Dynamic Type text styles (`Font.title`, `.body`, `.caption`, etc.) — never hardcode font sizes.
- **Color.** Use semantic system colors (`Color.primary`, `Color.secondary`, `Color.accentColor`, `.background`, etc.) to support Dark Mode and accessibility automatically.
- **Spacing and layout.** Prefer system-defined spacing and safe area insets. Avoid magic numbers.
- **Iconography.** Use SF Symbols. Do not bundle custom icons for concepts already covered by SF Symbols.
- **Animations.** Use system animations and transitions. Avoid custom timing curves unless the design explicitly requires them.
- **Accessibility.** Every interactive element must have a meaningful accessibility label. Use `.accessibilityLabel`, `.accessibilityHint`, and `.accessibilityAddTraits` where appropriate.

## SwiftUI Conventions
- Use `@Observable` (Swift Observation framework) over `ObservableObject`/`@StateObject` where possible (available iOS 17+, well within target).
- Prefer `NavigationStack` over `NavigationView`.
- Use `#Preview` macros for all previews.
- Do not build previews around SwiftData stores or `.modelContainer(...)` just to show sample content.
- Previews should inject fixed sample models or snapshot data through preview-specific services/wrapper views.
- Keep preview data generation separate from runtime persistence/query logic so previews stay stable and deterministic.
- Keep views small and composable — extract subviews aggressively.

## General Rules
- Write Swift only. No Objective-C.
- No third-party dependencies without explicit approval.
- Do not use deprecated APIs.
