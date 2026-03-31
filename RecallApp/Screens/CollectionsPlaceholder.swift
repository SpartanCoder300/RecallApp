import SwiftUI

/// Placeholder for the Collections tab — replaced when Collections is built.
struct CollectionsPlaceholder: View {
    var body: some View {
        VStack(spacing: DT.Spacing.md) {
            Image(systemName: "square.stack.fill")
                .font(DT.Typography.largeTitle)
                .foregroundStyle(DT.Color.textTertiary)

            Text("Collections")
                .font(DT.Typography.title2)
                .fontWeight(.bold)
                .foregroundStyle(DT.Color.textPrimary)

            Text("Coming in the next build")
                .font(DT.Typography.body)
                .foregroundStyle(DT.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DT.Color.background)
    }
}
