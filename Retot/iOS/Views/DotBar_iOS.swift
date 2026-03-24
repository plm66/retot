import SwiftUI

struct DotBar_iOS: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<appState.notes.count, id: \.self) { index in
                    DotButton_iOS(index: index)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct DotButton_iOS: View {
    @EnvironmentObject var appState: AppState
    let index: Int

    private var note: Note { appState.notes[index] }
    private var isSelected: Bool { appState.selectedNoteIndex == index }
    private var hasContent: Bool { appState.noteHasContent(index) }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(note.color.swiftUIColor)
                    .frame(width: isSelected ? 36 : 28, height: isSelected ? 36 : 28)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                    )
                    .shadow(
                        color: isSelected ? note.color.swiftUIColor.opacity(0.4) : .clear,
                        radius: 4
                    )

                // Content indicator
                if hasContent {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 5, height: 5)
                        .shadow(color: .black.opacity(0.3), radius: 1)
                        .offset(x: 2, y: -2)
                }
            }

            Text(note.label)
                .font(.caption2)
                .lineLimit(1)
                .foregroundColor(isSelected ? .primary : .secondary)
        }
        .frame(width: 48)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                appState.selectNote(index)
            }
        }
    }
}
