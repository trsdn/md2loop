import Cocoa

struct ClipboardSnapshot: Equatable {
    let changeCount: Int
    let text: String?
    let html: String?
    let rtfData: Data?

    var mode: ClipboardMode {
        ClipboardContentDetector.mode(text: text, html: html, rtfData: rtfData)
    }

    var contentLength: Int {
        text?.count ?? html?.count ?? rtfData?.count ?? 0
    }
}

enum ClipboardAccessError: LocalizedError, Equatable {
    case changedDuringRead
    case unavailableRepresentation(String)
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .changedDuringRead:
            return "Clipboard changed while it was being read. Try again."
        case .unavailableRepresentation:
            return "Could not read the current clipboard contents."
        case .writeFailed:
            return "Could not write the converted clipboard contents."
        }
    }
}

protocol ClipboardAccessing: AnyObject {
    func readSnapshot() throws -> ClipboardSnapshot
    func writeForLoop(html: String, markdown: String) throws
    func writeMarkdown(_ markdown: String) throws
}

final class SystemClipboard: ClipboardAccessing {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func readSnapshot() throws -> ClipboardSnapshot {
        let initialChangeCount = pasteboard.changeCount
        let types = Set(pasteboard.types ?? [])

        let text = types.contains(.string) ? pasteboard.string(forType: .string) : nil
        let html = types.contains(.html) ? pasteboard.string(forType: .html) : nil
        let rtfData = types.contains(.rtf) ? pasteboard.data(forType: .rtf) : nil

        guard initialChangeCount == pasteboard.changeCount else {
            throw ClipboardAccessError.changedDuringRead
        }
        if types.contains(.string), text == nil {
            throw ClipboardAccessError.unavailableRepresentation(NSPasteboard.PasteboardType.string.rawValue)
        }
        if types.contains(.html), html == nil {
            throw ClipboardAccessError.unavailableRepresentation(NSPasteboard.PasteboardType.html.rawValue)
        }
        if types.contains(.rtf), rtfData == nil {
            throw ClipboardAccessError.unavailableRepresentation(NSPasteboard.PasteboardType.rtf.rawValue)
        }

        return ClipboardSnapshot(
            changeCount: initialChangeCount,
            text: text,
            html: html,
            rtfData: rtfData
        )
    }

    func writeForLoop(html: String, markdown: String) throws {
        let item = NSPasteboardItem()
        guard item.setString(html, forType: .html),
              item.setString(markdown, forType: .string) else {
            throw ClipboardAccessError.writeFailed
        }

        if let htmlData = html.data(using: .utf8),
           let attributedString = NSAttributedString(html: htmlData, documentAttributes: nil) {
            let range = NSRange(location: 0, length: attributedString.length)
            if let rtfData = attributedString.rtf(from: range, documentAttributes: [:]) {
                guard item.setData(rtfData, forType: .rtf) else {
                    throw ClipboardAccessError.writeFailed
                }
            }
        }

        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else {
            throw ClipboardAccessError.writeFailed
        }
    }

    func writeMarkdown(_ markdown: String) throws {
        let item = NSPasteboardItem()
        guard item.setString(markdown, forType: .string) else {
            throw ClipboardAccessError.writeFailed
        }

        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else {
            throw ClipboardAccessError.writeFailed
        }
    }
}

enum ClipboardConversionError: LocalizedError, Equatable {
    case unsupportedContent
    case plainTextUnavailable
    case richTextConversionFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedContent:
            return "Unrecognized clipboard format."
        case .plainTextUnavailable:
            return "Clipboard has no plain text to convert to Loop."
        case .richTextConversionFailed:
            return "Could not convert the current rich text."
        }
    }
}

enum ClipboardConversionAction: Equatable {
    case toLoop
    case toMarkdown
}

struct ClipboardConversionResult: Equatable {
    let action: ClipboardConversionAction
    let sourceChangeCount: Int
}

struct ClipboardConversionService {
    private let clipboard: any ClipboardAccessing

    init(clipboard: any ClipboardAccessing) {
        self.clipboard = clipboard
    }

    func convertCurrentSnapshot(
        using requestedAction: ClipboardConversionAction? = nil
    ) throws -> ClipboardConversionResult {
        let snapshot = try clipboard.readSnapshot()
        let action: ClipboardConversionAction

        if let requestedAction {
            action = requestedAction
        } else {
            switch snapshot.mode {
            case .markdown:
                action = .toLoop
            case .richText:
                action = .toMarkdown
            case .unknown:
                throw ClipboardConversionError.unsupportedContent
            }
        }

        switch action {
        case .toLoop:
            guard let markdown = snapshot.text,
                  !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ClipboardConversionError.plainTextUnavailable
            }
            let html = LoopHTMLConverter.convert(markdown)
            try clipboard.writeForLoop(html: html, markdown: markdown)

        case .toMarkdown:
            guard let markdown = ClipboardMarkdownConverter.convert(snapshot) else {
                throw ClipboardConversionError.richTextConversionFailed
            }
            try clipboard.writeMarkdown(markdown)
        }

        return ClipboardConversionResult(
            action: action,
            sourceChangeCount: snapshot.changeCount
        )
    }
}

enum ClipboardMarkdownConverter {
    static func convert(_ snapshot: ClipboardSnapshot) -> String? {
        if let html = snapshot.html, ClipboardContentDetector.containsHTML(html) {
            let markdown = HTMLToMarkdownConverter.convert(html)
            if !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return markdown
            }
        }

        if let rtfData = snapshot.rtfData, ClipboardContentDetector.containsRTF(rtfData) {
            let markdown = RichTextToMarkdownConverter.convertRTF(rtfData)
            if !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return markdown
            }
        }

        return nil
    }
}
