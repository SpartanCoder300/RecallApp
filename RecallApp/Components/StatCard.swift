import SwiftUI

/// A glanceable stat display. Large number, minimal label.
/// Used on the Today screen and future Insights screen.
struct StatCard: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.xs) {
            Text("\(value)")
                .font(.system(.largeTitle, design: .rounded).bold())
                .foregroundStyle(DT.Color.textPrimary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: value)

            Text(label)
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DT.Spacing.md)
        .background(DT.Color.surface, in: RoundedRectangle(cornerRadius: DT.Radius.lg))
    }
}

#Preview {
    HStack {
        StatCard(value: 4, label: "Captured Today")
        StatCard(value: 7, label: "Due Now")
    }
    .padding()
}
