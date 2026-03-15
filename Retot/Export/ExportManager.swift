import AppKit
import Foundation

enum ExportManager {
    static func exportAsMarkdown(note: Note, content: NSAttributedString) {
        let markdown = MarkdownExporter.convert(content)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(note.label).md"
        panel.title = "Export Note as Markdown"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try markdown.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = "Could not save Markdown file: \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
}
