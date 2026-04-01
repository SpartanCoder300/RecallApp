import SwiftUI

struct ProUpgradeSheet: View {
    @Binding var isPresented: Bool
    @AppStorage(AppSettings.isProUserKey) private var isProUser = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: DT.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(DT.Typography.largeTitle)
                            .foregroundStyle(DT.Color.accent)
                        Text("Daily Recall Pro")
                            .font(DT.Typography.title2)
                            .fontWeight(.semibold)
                        Text("Supercharge your memory with on-device AI.")
                            .font(DT.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DT.Spacing.sm)
                }

                Section("What you get") {
                    FeatureRow(
                        icon: "brain.head.profile",
                        title: "AI Answer Grading",
                        description: "On-device AI compares your answer to the card and suggests a rating."
                    )
                    FeatureRow(
                        icon: "lock.open",
                        title: "More features coming",
                        description: "Voice recall, smart scheduling, and more."
                    )
                }

                Section {
                    Button {
                        // TODO: Replace with StoreKit purchase flow
                        isProUser = true
                        isPresented = false
                    } label: {
                        Text("Unlock Pro")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Unlock Daily Recall Pro")
                }
            }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}

// MARK: - FeatureRow

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: DT.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(DT.Color.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DT.Spacing.xs) {
                Text(title)
                    .font(DT.Typography.body)
                Text(description)
                    .font(DT.Typography.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DT.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
    }
}

#Preview {
    ProUpgradeSheet(isPresented: .constant(true))
}
