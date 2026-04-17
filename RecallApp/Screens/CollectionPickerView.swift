import SwiftUI
import SwiftData

struct CollectionPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecallCollection.name) private var collections: [RecallCollection]
    let item: RecallItem

    var body: some View {
        List {
            Section {
                rowButton(label: "None", color: nil, isSelected: item.collection == nil) {
                    item.collection = nil
                    try? modelContext.save()
                    HapticManager.light()
                }
            }

            if !collections.isEmpty {
                Section {
                    ForEach(collections) { collection in
                        rowButton(
                            label: collection.name,
                            color: collection.color.color,
                            isSelected: item.collection?.id == collection.id
                        ) {
                            item.collection = collection
                            try? modelContext.save()
                            HapticManager.light()
                        }
                    }
                }
            }
        }
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rowButton(
        label: String,
        color: Color?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DT.Spacing.md) {
                Image(systemName: color != nil ? "circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(color ?? DT.Color.textTertiary)
                    .frame(width: 20)

                Text(label)
                    .foregroundStyle(DT.Color.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DT.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DT.Color.accent)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
