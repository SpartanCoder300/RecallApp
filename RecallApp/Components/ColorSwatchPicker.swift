import SwiftUI

struct ColorSwatchPicker: View {
    @Binding var selectedColor: CollectionColor

    var body: some View {
        HStack(spacing: DT.Spacing.sm) {
            ForEach(CollectionColor.allCases, id: \.rawValue) { color in
                swatchButton(color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DT.Spacing.xs)
    }

    private func swatchButton(_ color: CollectionColor) -> some View {
        let isSelected = color == selectedColor
        return Button {
            HapticManager.light()
            selectedColor = color
        } label: {
            ZStack {
                Circle()
                    .fill(color.color)
                    .frame(width: 30, height: 30)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
        .accessibilityLabel("\(color.rawValue) color")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
