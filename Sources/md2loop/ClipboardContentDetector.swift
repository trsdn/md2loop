import Foundation

enum ClipboardMode: Equatable {
    case markdown
    case richText
    case unknown
}

struct ClipboardContentDetector {

    static func mode(text: String?, html: String?, rtfData: Data?) -> ClipboardMode {
        if containsHTML(html) {
            return .richText
        }
        if containsRTF(rtfData) {
            return .richText
        }
        if isMarkdown(text) {
            return .markdown
        }
        return .unknown
    }

    static func containsHTML(_ html: String?) -> Bool {
        guard let html = html?.trimmingCharacters(in: .whitespacesAndNewlines), !html.isEmpty else {
            return false
        }
        return html.range(
            of: #"<(html|body|p|div|span|h[1-6]|ul|ol|li|table|tr|td|th|blockquote|pre|code|strong|b|em|i|a|br|hr)\b[^>]*>"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    static func containsRTF(_ data: Data?) -> Bool {
        guard let data, !data.isEmpty else { return false }
        if let prefix = String(data: data.prefix(16), encoding: .ascii) {
            return prefix.contains(#"{\rtf"#)
        }
        return true
    }

    static func isMarkdown(_ text: String?) -> Bool {
        guard let text else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if containsHTML(trimmed) { return false }

        let lines = trimmed.components(separatedBy: .newlines)
        if lineMatches(lines, #"^\s{0,3}#{1,6}\s+\S"#) { return true }
        if lineMatches(lines, #"^\s{0,3}[-*+]\s+\S"#) { return true }
        if lineMatches(lines, #"^\s{0,3}\d+[.)]\s+\S"#) { return true }
        if lineMatches(lines, #"^\s{0,3}[-*+]\s+\[[ xX]\]\s+\S"#) { return true }
        if lineMatches(lines, #"^\s{0,3}>\s+\S"#) { return true }
        if lineMatches(lines, #"^\s*(```|~~~)"#) { return true }

        if hasMarkdownTable(lines) { return true }
        if trimmed.range(of: #"!?\[[^\]\n]+\]\([^)]+\)"#, options: .regularExpression) != nil { return true }
        if trimmed.range(of: #"`[^`\n]+`"#, options: .regularExpression) != nil { return true }
        if trimmed.range(of: #"(\*\*|__)[^\s].*?[^\s]\1"#, options: .regularExpression) != nil { return true }
        if trimmed.range(
            of: #"(^|[\s(])\*[^\s*][^*\n]*[^\s*]\*($|[\s).,!?:;])"#,
            options: .regularExpression
        ) != nil {
            return true
        }

        return false
    }

    private static func lineMatches(_ lines: [String], _ pattern: String) -> Bool {
        lines.contains { line in
            line.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private static func hasMarkdownTable(_ lines: [String]) -> Bool {
        let hasPipeRow = lines.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("|") && trimmed.hasSuffix("|")
        }
        let hasSeparator = lines.contains { line in
            line.range(
                of: #"^\s{0,3}\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$"#,
                options: .regularExpression
            ) != nil
        }
        return hasPipeRow && hasSeparator
    }
}