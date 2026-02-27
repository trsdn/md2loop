import SwiftUI
import Combine
import AppKit

struct ContentView: View {
    @State private var clipboardText: String? = nil
    @State private var clipboardHTML: String? = nil
    @State private var clipboardLength: Int = 0
    @State private var feedbackMessage: String? = nil
    @State private var feedbackIsSuccess: Bool = true
    @State private var lastChangeCount: Int = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var clipboardMode: ClipboardMode {
        if isHTML { return .html }
        if isMarkdown { return .markdown }
        return .unknown
    }

    var body: some View {
        VStack(spacing: 16) {
            clipboardStatusView
            convertButton
            feedbackView
        }
        .padding(20)
        .frame(width: 280)
        .onReceive(timer) { _ in
            pollClipboard()
        }
        .animation(.default, value: feedbackMessage)
        .animation(.default, value: clipboardMode)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var clipboardStatusView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundStyle(.secondary)
                if clipboardLength > 0 {
                    Text("\(clipboardLength) characters")
                } else {
                    Text("Empty")
                }
            }
            .font(.body)

            HStack(spacing: 4) {
                switch clipboardMode {
                case .markdown:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Markdown")
                case .html:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Rich Text")
                case .unknown:
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.secondary)
                    Text("Unrecognized format")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var convertButton: some View {
        Button {
            convert()
        } label: {
            HStack {
                switch clipboardMode {
                case .markdown:
                    Label("Convert to Loop", systemImage: "arrow.right")
                case .html:
                    Label("Convert to Markdown", systemImage: "arrow.left")
                case .unknown:
                    Label("Convert", systemImage: "arrow.left.arrow.right")
                }
                Spacer()
                Text("⌘⏎")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(clipboardMode == .unknown)
    }

    @ViewBuilder
    private var feedbackView: some View {
        if let message = feedbackMessage {
            HStack(spacing: 6) {
                Image(systemName: feedbackIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                Text(message)
            }
            .font(.subheadline)
            .foregroundStyle(feedbackIsSuccess ? .green : .red)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Detection

    private enum ClipboardMode: Equatable {
        case markdown, html, unknown
    }

    private var isHTML: Bool {
        guard let html = clipboardHTML, !html.isEmpty else { return false }
        return html.range(of: #"<[a-zA-Z][^>]*>"#, options: .regularExpression) != nil
    }

    private var isMarkdown: Bool {
        guard let text = clipboardText, !text.isEmpty else { return false }
        if isHTML { return false }
        let lines = text.components(separatedBy: "\n")
        var signals = 0

        if lines.contains(where: { $0.range(of: #"^#{1,6}\s"#, options: .regularExpression) != nil }) {
            signals += 1
        }
        if text.contains("**") || text.range(of: #"(?<!\*)\*[^\s*]"#, options: .regularExpression) != nil {
            signals += 1
        }
        if lines.contains(where: { $0.range(of: #"^\s*[-*]\s"#, options: .regularExpression) != nil }) {
            signals += 1
        }
        if lines.contains(where: { $0.range(of: #"^\s*\d+\.\s"#, options: .regularExpression) != nil }) {
            signals += 1
        }
        if text.contains("`") {
            signals += 1
        }
        if text.range(of: #"\[.+?\]\(.+?\)"#, options: .regularExpression) != nil {
            signals += 1
        }
        if lines.contains(where: { $0.range(of: #"^\|.+\|$"#, options: .regularExpression) != nil }) {
            signals += 1
        }
        if lines.contains(where: { $0.hasPrefix("> ") }) {
            signals += 1
        }
        if text.contains("- [ ]") || text.contains("- [x]") || text.contains("- [X]") {
            signals += 1
        }

        let hasStrongSignal = lines.contains(where: { $0.range(of: #"^#{1,6}\s"#, options: .regularExpression) != nil })
            || text.range(of: #"\[.+?\]\(.+?\)"#, options: .regularExpression) != nil
            || lines.contains(where: { $0.range(of: #"^\|.+\|$"#, options: .regularExpression) != nil })
            || text.contains("- [ ]") || text.contains("- [x]") || text.contains("- [X]")
            || text.contains("```")

        return hasStrongSignal || signals >= 2
    }

    // MARK: - Actions

    private func pollClipboard() {
        let changeCount = NSPasteboard.general.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount
        clipboardText = ClipboardManager.readText()
        clipboardHTML = ClipboardManager.readHTML()
        clipboardLength = clipboardText?.count ?? 0
    }

    private func convert() {
        if isHTML {
            convertToMarkdown()
        } else if isMarkdown {
            convertToLoop()
        }
    }

    private func convertToLoop() {
        guard let markdown = clipboardText, !markdown.isEmpty else { return }
        let html = LoopHTMLConverter.convert(markdown)
        ClipboardManager.writeForLoop(html: html, markdown: markdown)
        showFeedback("Ready to paste into Loop", isSuccess: true)
    }

    private func convertToMarkdown() {
        guard let html = clipboardHTML, !html.isEmpty else { return }
        let markdown = HTMLToMarkdownConverter.convert(html)
        ClipboardManager.writeMarkdown(markdown)
        showFeedback("Markdown copied", isSuccess: true)
    }

    private func showFeedback(_ message: String, isSuccess: Bool) {
        feedbackMessage = message
        feedbackIsSuccess = isSuccess
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if feedbackMessage == message {
                feedbackMessage = nil
            }
        }
    }
}
