import SwiftUI
import Combine

struct ContentView: View {
    @State private var clipboardText: String? = nil
    @State private var clipboardHTML: String? = nil
    @State private var clipboardRTF: Data? = nil
    @State private var clipboardLength: Int = 0
    @State private var feedbackMessage: String? = nil
    @State private var feedbackIsSuccess: Bool = true
    @State private var lastChangeCount: Int? = nil
    @State private var isConverting = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let clipboard: any ClipboardAccessing

    init(clipboard: any ClipboardAccessing = SystemClipboard()) {
        self.clipboard = clipboard
    }

    private var clipboardMode: ClipboardMode {
        ClipboardContentDetector.mode(text: clipboardText, html: clipboardHTML, rtfData: clipboardRTF)
    }

    private var canConvertToLoop: Bool {
        !(clipboardText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private var canConvertToMarkdown: Bool {
        ClipboardContentDetector.containsHTML(clipboardHTML)
            || ClipboardContentDetector.containsRTF(clipboardRTF)
    }

    var body: some View {
        VStack(spacing: 16) {
            clipboardStatusView
            conversionButtons
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
                    Text("Detected Markdown")
                case .richText:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Detected Rich Text")
                case .unknown:
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.secondary)
                    Text("Detection uncertain")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var conversionButtons: some View {
        VStack(spacing: 8) {
            conversionButton(
                title: "Convert to Loop",
                systemImage: "arrow.right",
                action: .toLoop,
                isEnabled: canConvertToLoop,
                isRecommended: clipboardMode == .markdown
            )
            conversionButton(
                title: "Convert to Markdown",
                systemImage: "arrow.left",
                action: .toMarkdown,
                isEnabled: canConvertToMarkdown,
                isRecommended: clipboardMode == .richText
            )
        }
    }

    @ViewBuilder
    private func conversionButton(
        title: String,
        systemImage: String,
        action: ClipboardConversionAction,
        isEnabled: Bool,
        isRecommended: Bool
    ) -> some View {
        let button = Button {
            convert(using: action)
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                if isRecommended {
                    Text("⌘⏎")
                        .font(.subheadline)
                        .opacity(0.7)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .accessibilityLabel(title)
        .disabled(!isEnabled || isConverting)

        if isRecommended {
            button
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
        } else {
            button.buttonStyle(.bordered)
        }
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

    // MARK: - Actions

    private func pollClipboard() {
        guard !isConverting else { return }

        do {
            let snapshot = try clipboard.readSnapshot()
            guard snapshot.changeCount != lastChangeCount else { return }
            lastChangeCount = snapshot.changeCount
            clipboardText = snapshot.text
            clipboardHTML = snapshot.html
            clipboardRTF = snapshot.rtfData
            clipboardLength = snapshot.contentLength
        } catch {
            showFeedback(error.localizedDescription, isSuccess: false)
        }
    }

    private func convert(using action: ClipboardConversionAction) {
        guard !isConverting else { return }
        isConverting = true

        do {
            let result = try ClipboardConversionService(clipboard: clipboard)
                .convertCurrentSnapshot(using: action)
            switch result.action {
            case .toLoop:
                showFeedback("Ready to paste into Loop", isSuccess: true)
            case .toMarkdown:
                showFeedback("Markdown copied", isSuccess: true)
            }
        } catch {
            showFeedback(error.localizedDescription, isSuccess: false)
        }

        isConverting = false
        pollClipboard()
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
