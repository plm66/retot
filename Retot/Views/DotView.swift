import SwiftUI

struct DotView: View {
    let note: Note
    let isSelected: Bool
    let onTap: () -> Void
    let onSettings: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(note.color.swiftUIColor)
                    .frame(width: dotSize, height: dotSize)
                    .shadow(
                        color: isSelected ? note.color.swiftUIColor.opacity(0.6) : .clear,
                        radius: 4
                    )
                    .scaleEffect(isHovering ? 1.15 : (isSelected ? 1.1 : 1.0))

                Text("\(note.id)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(note.label)
                .font(.system(size: 8))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .frame(maxWidth: 48)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button("Rename...") { onSettings() }
            Button("Change Color...") { onSettings() }
        }
        .accessibilityLabel("Note \(note.id): \(note.label)")
    }

    private var dotSize: CGFloat { 28 }
}
