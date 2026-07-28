import Foundation

enum ClipboardMode: Equatable {
    case markdown
    case richText
    case unknown
}

struct ClipboardContentDetector {

    static func mode(text: String?, html: String?, rtfData: Data?) -> ClipboardMode {
        let hasText = !(text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        if containsHTML(html) {
            let markdownScore = markdownScore(text)
            let richTextScore = richTextScore(html)

            // Editors often put syntax-highlighted HTML beside the original Markdown.
            // Prefer the source only when it has stronger semantic evidence than the HTML.
            if markdownScore >= 3, markdownScore > richTextScore {
                return .markdown
            }
            return .richText
        }

        if containsRTF(rtfData) {
            return .richText
        }

        // Plain prose is valid Markdown input even without visible Markdown punctuation.
        return hasText ? .markdown : .unknown
    }

    static func containsHTML(_ html: String?) -> Bool {
        guard let html = html?.trimmingCharacters(in: .whitespacesAndNewlines), !html.isEmpty else {
            return false
        }
        return html.range(
            of: #"<(html|body|article|section|main|p|div|span|h[1-6]|ul|ol|li|dl|dt|dd|table|thead|tbody|tfoot|tr|td|th|blockquote|pre|code|strong|b|em|i|s|del|strike|a|img|br|hr)\b[^>]*>"#,
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
        markdownScore(text) >= 3
    }

    private static func markdownScore(_ text: String?) -> Int {
        guard let text else { return 0 }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        if containsHTML(trimmed) { return 0 }

        let lines = trimmed.components(separatedBy: .newlines)
        let hasSetextHeading = hasSetextHeading(lines)
        let hasTaskList = lineMatches(lines, #"^\s{0,3}[-*+]\s+\[[ xX]\]\s+\S"#)
        var score = 0

        if lineMatches(lines, #"^\s{0,3}#{1,6}\s+\S"#) || hasSetextHeading { score += 6 }
        if hasTaskList { score += 6 }
        if lineMatches(lines, #"^\s*(```|~~~)"#) { score += 6 }
        if hasMarkdownTable(lines) { score += 6 }
        if !hasTaskList, lineMatches(lines, #"^\s{0,3}[-*+]\s+\S"#) { score += 3 }
        if lineMatches(lines, #"^\s{0,3}\d+[.)]\s+\S"#) { score += 3 }
        if lineMatches(lines, #"^\s{0,3}>\s+\S"#) { score += 3 }
        if !hasSetextHeading,
           lineMatches(lines, #"^\s{0,3}((\*\s*){3,}|(-\s*){3,}|(_\s*){3,})$"#) {
            score += 3
        }
        if matches(trimmed, #"!?\[[^\]\n]*\]\([^)]+\)"#) { score += 4 }
        if matches(trimmed, #"`[^`\n]+`"#) { score += 3 }
        if matches(trimmed, #"(\*\*|__)(?=\S)(.+?)(?<=\S)\1"#) { score += 4 }
        if matches(
            trimmed,
            #"(?:^|[\s(])\*(?=\S)([^*\n]*?\S)\*(?=$|[\s).,!?:;])|(?:^|[\s(])_(?=\S)([^_\n]*?\S)_(?=$|[\s).,!?:;])"#
        ) {
            score += 3
        }
        if matches(trimmed, #"~~(?=\S)(.+?)(?<=\S)~~"#) { score += 3 }

        return score
    }

    private static func richTextScore(_ html: String?) -> Int {
        guard let html else { return 0 }
        var score = 0
        let hasPreformattedContent = matches(html, #"<pre\b"#)

        if matches(html, #"<h[1-6]\b"#) { score += 6 }
        if matches(html, #"<(ul|ol|li)\b"#) { score += 7 }
        if matches(html, #"<(table|thead|tbody|tfoot|tr|td|th)\b"#) { score += 6 }
        if matches(html, #"<blockquote\b"#) { score += 4 }
        if hasPreformattedContent { score += 5 }
        if matches(html, #"<(strong|b)\b"#) { score += 4 }
        if matches(html, #"<(em|i)\b"#) { score += 3 }
        if matches(html, #"<(a|img)\b"#) { score += 4 }
        if matches(html, #"<code\b"#) { score += 3 }
        if matches(html, #"<(s|del|strike)\b"#) { score += 3 }
        if matches(
            html,
            #"style\s*=\s*["'][^"']*(font-weight\s*:\s*(bold|[6-9]00)|font-style\s*:\s*italic|text-decoration[^;"']*(underline|line-through))"#
        ) {
            score += 3
        }
        if !hasPreformattedContent, matches(html, #"<(p|div|span|br)\b"#) { score += 1 }

        return score
    }

    private static func lineMatches(_ lines: [String], _ pattern: String) -> Bool {
        lines.contains { line in
            line.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func hasSetextHeading(_ lines: [String]) -> Bool {
        guard lines.count > 1 else { return false }
        for index in 1..<lines.count {
            if !lines[index - 1].trimmingCharacters(in: .whitespaces).isEmpty,
               lines[index].range(
                   of: #"^\s{0,3}(=+|-+)\s*$"#,
                   options: .regularExpression
               ) != nil {
                return true
            }
        }
        return false
    }

    private static func hasMarkdownTable(_ lines: [String]) -> Bool {
        guard lines.count > 1 else { return false }
        for index in 1..<lines.count {
            if lines[index - 1].contains("|"),
               lines[index].range(
                of: #"^\s{0,3}\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$"#,
                options: .regularExpression
               ) != nil {
                return true
            }
        }
        return false
    }
}
