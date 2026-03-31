import SwiftUI

struct HomeScreen: View {
    var body: some View {
        ZStack {
            DT.Color.background.ignoresSafeArea()

            VStack(spacing: DT.Spacing.lg) {
                Spacer()

                VStack(spacing: DT.Spacing.sm) {
                    Text("Daily Recall")
                        .font(DT.Typography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(DT.Color.textPrimary)

                    Text("Foundation ready.")
                        .font(DT.Typography.body)
                        .foregroundStyle(DT.Color.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, DT.Spacing.lg)
        }
    }
}

#Preview {
    HomeScreen()
}

#Preview("Dark Mode") {
    HomeScreen()
        .preferredColorScheme(.dark)
}
