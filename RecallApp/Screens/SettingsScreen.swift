import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        NavigationStack {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DT.Color.background)
                .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsScreen()
}
