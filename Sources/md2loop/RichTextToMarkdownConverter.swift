import AppKit
import Foundation

struct RichTextToMarkdownConverter {

    static func convertRTF(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        guard let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else {
            return ""
        }
        return convert(attributedString)
    }

    static func convert(_ attributedString: NSAttributedString) -> String {
        let range = NSRange(location: 0, length: attributedString.length)
        guard range.length > 0 else { return "" }

        if let htmlData = try? attributedString.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
        ), let html = String(data: htmlData, encoding: .utf8) ?? String(data: htmlData, encoding: .utf16) {
            let markdown = HTMLToMarkdownConverter.convert(html)
            if !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return markdown
            }
        }

        return attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}