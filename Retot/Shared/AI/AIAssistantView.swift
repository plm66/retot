import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .foregroundColor(.accentColor)
                Text("Assistant")
                    .font(.headline)
                Spacer()
                Button(action: { appState.showAIAssistant = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(
                            Array(appState.assistantMessages.enumerated()),
                            id: \.offset
                        ) { index, message in
                            MessageBubble(role: message.role, content: message.content)
                                .id(index)
                        }
                        if appState.assistantProcessing {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Reflexion...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .id("loading")
                        }
                    }
                    .padding()
                }
                .onChange(of: appState.assistantMessages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(appState.assistantMessages.count - 1, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input
            HStack(spacing: 8) {
                TextField("Posez une question...", text: $inputText)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(
                            inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? .secondary : .accentColor
                        )
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || appState.assistantProcessing)
            }
            .padding()
        }
        .frame(width: 500, height: 480)
        .onAppear {
            isInputFocused = true
            if appState.assistantMessages.isEmpty {
                appState.assistantMessages = [
                    (role: "assistant",
                     content: "Bonjour ! Je suis votre assistant. Je peux chercher dans vos notes, les lister, ou repondre a vos questions. Que puis-je faire pour vous ?")
                ]
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        appState.sendAssistantMessage(text)
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let role: String
    let content: String

    var body: some View {
        HStack {
            if role == "user" { Spacer(minLength: 60) }

            VStack(alignment: role == "user" ? .trailing : .leading, spacing: 2) {
                Text(content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        role == "user"
                            ? Color.accentColor.opacity(0.15)
                            : Color.secondary.opacity(0.1)
                    )
                    .cornerRadius(12)
            }

            if role == "assistant" { Spacer(minLength: 60) }
        }
    }
}
