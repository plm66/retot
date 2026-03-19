import SwiftUI

struct DotView: View {
    let note: Note
    let isSelected: Bool
    let onTap: () -> Void
    let onSettings: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // White ring around selected dot
                Circle()
                    .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                    .frame(width: dotSize + 6, height: dotSize + 6)
                    .opacity(isSelected ? 1 : 0)

                Circle()
                    .fill(note.color.swiftUIColor)
                    .frame(width: dotSize, height: dotSize)
                    .shadow(
                        color: isSelected ? note.color.swiftUIColor.opacity(0.6) : .clear,
                        radius: 4
                    )
                    .scaleEffect(isHovering ? 1.1 : 1.0)

                Text("\(note.id)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: dotSize + 8, height: dotSize + 8)

            Text(note.label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
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
