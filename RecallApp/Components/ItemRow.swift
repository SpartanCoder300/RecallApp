import SwiftUI
import SwiftData

/// A single row representing a RecallItem in a list.
struct ItemRow: View {
    let item: RecallItem

    var body: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DT.Spacing.sm) {
                Text(item.term)
                    .font(DT.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DT.Color.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: DT.Spacing.sm)

                StatusBadge(status: item.status)
            }

            if let note = item.note, !note.isEmpty {
                Text(note)
                    .font(DT.Typography.footnote)
                    .foregroundStyle(DT.Color.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, DT.Spacing.xs)
        .contentShape(Rectangle())
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: ItemStatus

    var body: some View {
        Text(status.label)
            .font(DT.Typography.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(badgeColor)
            .padding(.horizontal, DT.Spacing.sm - 2)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.14), in: Capsule())
    }

    private var badgeColor: Color {
        switch status {
        case .new:      return DT.Color.accent
        case .due:      return DT.Color.accent
        case .upcoming: return DT.Color.textSecondary
        case .mastered: return DT.Color.success
        }
    }
}

// MARK: - Previews

#Preview("With note") {
    List {
        ItemRow(item: PreviewService.itemWithNote)
    }
}

#Preview("No note") {
    List {
        ItemRow(item: PreviewService.itemWithoutNote)
    }
}
