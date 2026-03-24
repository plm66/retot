import SwiftUI

struct EditorToolbar_iOS: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            Button(action: { appState.applyBold_iOS() }) {
                Image(systemName: "bold")
                    .font(.system(size: 16))
            }

            Button(action: { appState.applyItalic_iOS() }) {
                Image(systemName: "italic")
                    .font(.system(size: 16))
            }

            Button(action: { appState.applyUnderline_iOS() }) {
                Image(systemName: "underline")
                    .font(.system(size: 16))
            }

            Divider()
                .frame(height: 20)

            Button(action: { appState.applyHeading_iOS() }) {
                Image(systemName: "textformat.size.larger")
                    .font(.system(size: 16))
            }

            Divider()
                .frame(height: 20)

            Button(action: { appState.showAIPopover.toggle() }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
            }

            Spacer()

            Button(action: dismissKeyboard) {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 16))
            }
        }
    }

    private func dismissKeyboard() {
        appState.currentTextView_iOS?.resignFirstResponder()
    }
}
