import SwiftUI

/// Placeholder for the Collections tab — replaced when Collections is built.
struct CollectionsPlaceholder: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Collections", systemImage: "square.stack.fill")
            } description: {
                Text("Coming in the next build")
            }
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
