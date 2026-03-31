import SwiftUI
import SwiftData

struct HomeScreen: View {
    @Query(sort: \RecallItem.createdAt, order: .reverse) private var allItems: [RecallItem]
    @Query private var allReviews: [Review]
    @State private var showingRecallSession = false

    var body: some View {
        HomeScreenContent(
            snapshot: HomeScreenSnapshot.makePreviewSnapshot(
                allItems: allItems,
                allReviews: allReviews,
                now: Date()
            ),
            onBeginReview: { showingRecallSession = true }
        )
        .fullScreenCover(isPresented: $showingRecallSession) {
            RecallSessionScreen(items: allItems.filter(\.isDue))
        }
    }
}

struct HomeScreenPreview: View {
    let snapshot: HomeScreenSnapshot

    var body: some View {
        HomeScreenContent(snapshot: snapshot, onBeginReview: { })
    }
}

struct HomeScreenSnapshot {
    let greeting: String
    let streak: Int
    let dueCount: Int
    let todaysItems: [RecallItem]
    let previousDueItems: [RecallItem]

    static func makePreviewSnapshot(
        allItems: [RecallItem],
        allReviews: [Review],
        now: Date
    ) -> HomeScreenSnapshot {
        let calendar = Calendar.current
        let todaysItems = allItems.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }
        let dueItems = allItems.filter(\.isDue)
        let previousDueItems = dueItems.filter { !calendar.isDate($0.createdAt, inSameDayAs: now) }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var activeDays = Set<String>()
        allItems.forEach { activeDays.insert(formatter.string(from: $0.createdAt)) }
        allReviews.forEach { activeDays.insert(formatter.string(from: $0.reviewedAt)) }

        var streak = 0
        var date = now
        while activeDays.contains(formatter.string(from: date)) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previousDay
        }

        return HomeScreenSnapshot(
            greeting: greeting(for: now),
            streak: streak,
            dueCount: dueItems.count,
            todaysItems: todaysItems,
            previousDueItems: previousDueItems
        )
    }

    static func greeting(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Good night"
        }
    }
}

private struct HomeScreenContent: View {
    let snapshot: HomeScreenSnapshot
    let onBeginReview: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DT.Spacing.lg) {
                headerRow

                if snapshot.dueCount > 0 {
                    ReviewBanner(count: snapshot.dueCount, onBeginReview: onBeginReview)
                }

                statsRow

                if !snapshot.todaysItems.isEmpty {
                    itemSection(title: "TODAY", items: snapshot.todaysItems)
                }

                if !snapshot.previousDueItems.isEmpty {
                    itemSection(title: "DUE FROM BEFORE", items: snapshot.previousDueItems)
                }

                if snapshot.todaysItems.isEmpty, snapshot.previousDueItems.isEmpty, snapshot.dueCount == 0 {
                    emptyPrompt
                }

                Color.clear.frame(height: DT.Spacing.xxl + DT.Spacing.xl)
            }
            .padding(.horizontal, DT.Spacing.lg)
            .padding(.top, DT.Spacing.md)
        }
        .background(DT.Color.background.ignoresSafeArea())
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.greeting)
                    .font(DT.Typography.subheadline)
                    .foregroundStyle(DT.Color.textSecondary)

                Text("Today")
                    .font(DT.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(DT.Color.textPrimary)
            }

            Spacer()

            StreakChip(streak: snapshot.streak)
                .padding(.top, DT.Spacing.xs)
        }
    }

    private var statsRow: some View {
        HStack(spacing: DT.Spacing.md) {
            StatCard(value: snapshot.todaysItems.count, label: "Captured Today")
            StatCard(value: snapshot.dueCount, label: "Due Now")
        }
    }

    private func itemSection(title: String, items: [RecallItem]) -> some View {
        VStack(alignment: .leading, spacing: DT.Spacing.xs) {
            Text(title)
                .font(DT.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DT.Color.textTertiary)
                .padding(.top, DT.Spacing.xs)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    TodayItemRow(item: item)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, DT.Spacing.md)
                    }
                }
            }
            .background(DT.Color.surface, in: RoundedRectangle(cornerRadius: DT.Radius.lg))
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: items.count)
        }
    }

    private var emptyPrompt: some View {
        VStack(spacing: DT.Spacing.sm) {
            Text("Nothing captured yet today")
                .font(DT.Typography.subheadline)
                .foregroundStyle(DT.Color.textSecondary)

            Text("Tap + to add your first learning")
                .font(DT.Typography.footnote)
                .foregroundStyle(DT.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DT.Spacing.xxl)
    }
}

private struct StreakChip: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)

            Text("\(streak)d")
                .fontWeight(.semibold)
                .foregroundStyle(DT.Color.textPrimary)
        }
        .font(DT.Typography.footnote)
        .padding(.horizontal, DT.Spacing.sm)
        .padding(.vertical, 5)
        .background(DT.Color.surface, in: Capsule())
    }
}

private struct ReviewBanner: View {
    let count: Int
    let onBeginReview: () -> Void

    var body: some View {
        HStack(spacing: DT.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) \(count == 1 ? "item" : "items") ready to review")
                    .font(DT.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(DT.Color.textPrimary)

                Text("Tonight's session is waiting")
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }

            Spacer(minLength: DT.Spacing.sm)

            Button("Begin", action: onBeginReview)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
        .padding(DT.Spacing.md)
        .background(DT.Color.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: DT.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DT.Radius.lg)
                .stroke(DT.Color.accent.opacity(0.25), lineWidth: 1)
        }
    }
}

private struct TodayItemRow: View {
    let item: RecallItem

    private var reviewedToday: Bool {
        (item.reviews ?? []).contains { Calendar.current.isDateInToday($0.reviewedAt) }
    }

    var body: some View {
        HStack(spacing: DT.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.term)
                    .font(DT.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DT.Color.textPrimary)
                    .lineLimit(1)

                Text(item.createdAt, style: .time)
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textTertiary)
            }

            Spacer()

            if reviewedToday {
                Image(systemName: "checkmark.circle.fill")
                    .font(DT.Typography.title3)
                    .foregroundStyle(DT.Color.success)
            } else {
                StatusBadge(status: item.status)
            }
        }
        .padding(.horizontal, DT.Spacing.md)
        .padding(.vertical, DT.Spacing.sm + 2)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

#Preview("With items") {
    HomeScreenContent(snapshot: PreviewService.homeSnapshot, onBeginReview: { })
}

#Preview("Empty state") {
    HomeScreenContent(snapshot: PreviewService.emptyHomeSnapshot, onBeginReview: { })
}

#Preview("Dark mode") {
    HomeScreenContent(snapshot: PreviewService.homeSnapshot, onBeginReview: { })
        .preferredColorScheme(.dark)
}
