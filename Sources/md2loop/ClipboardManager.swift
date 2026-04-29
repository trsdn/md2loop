import Cocoa

class ClipboardManager {

    /// Read plain text from clipboard. Returns nil if no text content.
    static func readText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    /// Write converted content to clipboard in multiple formats for maximum Loop compatibility.
    /// Sets: .html (Loop-optimized HTML), .rtf (for Microsoft Office apps), .string (original markdown as fallback)
    static func writeForLoop(html: String, markdown: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.html, .rtf, .string], owner: nil)

        pasteboard.setString(html, forType: .html)

        if let htmlData = html.data(using: .utf8),
           let attributedString = NSAttributedString(html: htmlData, documentAttributes: nil) {
            let range = NSRange(location: 0, length: attributedString.length)
            if let rtfData = attributedString.rtf(from: range, documentAttributes: [:]) {
                pasteboard.setData(rtfData, forType: .rtf)
            }
        }

        pasteboard.setString(markdown, forType: .string)
    }

    /// Get the current clipboard change count (to detect clipboard changes)
    static func changeCount() -> Int {
        NSPasteboard.general.changeCount
    }

    static func readHTML() -> String? {
        NSPasteboard.general.string(forType: .html)
    }

    static func readRTF() -> Data? {
        NSPasteboard.general.data(forType: .rtf)
    }

    static func readRichTextMarkdown() -> String? {
        if let html = readHTML(), ClipboardContentDetector.containsHTML(html) {
            let markdown = HTMLToMarkdownConverter.convert(html)
            if !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return markdown
            }
        }

        if let rtfData = readRTF(), ClipboardContentDetector.containsRTF(rtfData) {
            let markdown = RichTextToMarkdownConverter.convertRTF(rtfData)
            if !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return markdown
            }
        }

        return nil
    }

    static func writeMarkdown(_ markdown: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(markdown, forType: .string)
    }

    static func hasHTML() -> Bool {
        NSPasteboard.general.types?.contains(.html) ?? false
    }
}
