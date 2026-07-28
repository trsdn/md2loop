import Foundation
import SwiftSoup

struct HTMLToMarkdownConverter {

    static func convert(_ html: String) -> String {
        guard !html.isEmpty else { return "" }
        do {
            let document = try SwiftSoup.parse(html)
            guard let body = document.body() else { return "" }
            let raw = convertChildren(
                body,
                listDepth: 0,
                inPre: false,
                startsAtLineStart: true
            )
            return normalizeMarkdown(raw)
        } catch {
            return ""
        }
    }

    // MARK: - Recursive node conversion

    private static func convertNode(
        _ node: Node,
        listDepth: Int,
        inPre: Bool,
        startsAtLineStart: Bool
    ) -> String {
        if let textNode = node as? TextNode {
            let text = textNode.getWholeText()
            if inPre {
                return text
            }
            if startsAtLineStart,
               text.contains(where: \.isNewline),
               text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ""
            }
            let collapsed = text.replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            return escapeMarkdownText(collapsed, startsAtLineStart: startsAtLineStart)
        }

        guard let element = node as? Element else {
            return ""
        }

        let tag = element.tagName().lowercased()

        switch tag {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(String(tag.last!)) ?? 1
            let prefix = String(repeating: "#", count: level)
            let content = convertChildren(
                element,
                listDepth: listDepth,
                inPre: false,
                startsAtLineStart: false
            ).trimmingCharacters(in: .whitespaces)
            return "\(prefix) \(content)\n\n"

        case "p":
            let content = convertChildren(
                element,
                listDepth: listDepth,
                inPre: false,
                startsAtLineStart: true
            ).trimmingCharacters(in: .whitespaces)
            return "\(content)\n\n"

        case "strong", "b":
            let content = convertChildren(
                element,
                listDepth: listDepth,
                inPre: inPre,
                startsAtLineStart: false
            )
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return content
            }
            return "**\(content)**"

        case "em", "i":
            let content = convertChildren(
                element,
                listDepth: listDepth,
                inPre: inPre,
                startsAtLineStart: false
            )
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return content
            }
            return "*\(content)*"

        case "s", "del", "strike":
            let content = convertChildren(
                element,
                listDepth: listDepth,
                inPre: inPre,
                startsAtLineStart: false
            )
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return content
            }
            return "~~\(content)~~"

        case "code":
            if inPre {
                return preservingWhitespaceText(element)
            }
            return inlineCode(preservingWhitespaceText(element))

        case "pre":
            let codeElement = try? element.select("code").first()
            let language = codeElement.flatMap(codeLanguage(from:)) ?? codeLanguage(from: element)
            let content = preservingWhitespaceText(codeElement ?? element)
            let fence = String(
                repeating: "`",
                count: max(3, longestRun(of: "`", in: content) + 1)
            )
            let closingSeparator = content.isEmpty || content.hasSuffix("\n") ? "" : "\n"
            return "\(fence)\(language ?? "")\n\(content)\(closingSeparator)\(fence)\n\n"

        case "a":
            let content = convertChildren(
                element,
                listDepth: listDepth,
                inPre: inPre,
                startsAtLineStart: false
            )
            let href = (try? element.attr("href")) ?? ""
            guard let destination = markdownDestination(href, forImage: false) else {
                return content
            }
            return "[\(content)](\(destination))"

        case "img":
            let source = (try? element.attr("src")) ?? ""
            let alt = (try? element.attr("alt")) ?? ""
            let escapedAlt = escapeMarkdownText(alt, startsAtLineStart: false)
            let destination = markdownDestination(source, forImage: true) ?? ""
            return "![\(escapedAlt)](\(destination))"

        case "ul":
            var result = ""
            for child in element.children() where child.tagName().lowercased() == "li" {
                var unusedIndex: Int? = nil
                result += convertListItem(
                    child,
                    listDepth: listDepth,
                    orderedIndex: &unusedIndex,
                    ordered: false
                )
            }
            return result

        case "ol":
            var result = ""
            var index: Int? = orderedListStart(element)
            for child in element.children() where child.tagName().lowercased() == "li" {
                result += convertListItem(
                    child,
                    listDepth: listDepth,
                    orderedIndex: &index,
                    ordered: true
                )
            }
            return result

        case "table":
            return convertTable(element)

        case "blockquote":
            let content = convertChildren(
                element,
                listDepth: listDepth,
                inPre: false,
                startsAtLineStart: true
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            let quoted = content
                .components(separatedBy: "\n")
                .map { $0.isEmpty ? ">" : "> \($0)" }
                .joined(separator: "\n")
            return "\(quoted)\n\n"

        case "hr":
            return "\n---\n\n"

        case "br":
            return "\n"

        case "div":
            let content = convertChildren(
                element,
                listDepth: listDepth,
                inPre: inPre,
                startsAtLineStart: startsAtLineStart
            )
            return "\(content)\n"

        case "span", "font":
            let content = convertChildren(
                element,
                listDepth: listDepth,
                inPre: inPre,
                startsAtLineStart: startsAtLineStart
            )
            return applyInlineStyle(to: content, style: (try? element.attr("style")) ?? "")

        default:
            return convertChildren(
                element,
                listDepth: listDepth,
                inPre: inPre,
                startsAtLineStart: startsAtLineStart
            )
        }
    }

    // MARK: - Lists

    private static func orderedListStart(_ list: Element) -> Int {
        let value = ((try? list.attr("start")) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let parsed = Int(value), parsed >= 0 else {
            return 1
        }
        return parsed
    }

    private static func convertListItem(
        _ item: Element,
        listDepth: Int,
        orderedIndex: inout Int?,
        ordered: Bool
    ) -> String {
        let indent = String(repeating: "    ", count: listDepth)
        let text = ((try? item.text()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasCheckedUnicode = text.hasPrefix("☑")
        let hasUncheckedUnicode = text.hasPrefix("☐")
        let checkedInput = (try? item.select("input[type=checkbox][checked]"))?.first() != nil
        let checkboxInput = (try? item.select("input[type=checkbox]"))?.first()
        let hasUncheckedInput = checkboxInput != nil && !checkedInput

        var inlineContent = ""
        var nestedContent = ""

        for child in item.getChildNodes() {
            if let childElement = child as? Element {
                let childTag = childElement.tagName().lowercased()
                if childTag == "ul" || childTag == "ol" {
                    nestedContent += convertNode(
                        childElement,
                        listDepth: listDepth + 1,
                        inPre: false,
                        startsAtLineStart: true
                    )
                    continue
                }
            }

            inlineContent += convertNode(
                child,
                listDepth: listDepth,
                inPre: false,
                startsAtLineStart: isAtLineStart(in: inlineContent, initial: false)
            )
        }

        let content = inlineContent.trimmingCharacters(in: .whitespacesAndNewlines)

        if hasCheckedUnicode || checkedInput {
            return "\(indent)- [x] \(removingLeadingCheckbox(from: content))\n\(nestedContent)"
        }
        if hasUncheckedUnicode || hasUncheckedInput {
            return "\(indent)- [ ] \(removingLeadingCheckbox(from: content))\n\(nestedContent)"
        }
        if ordered, let index = orderedIndex {
            orderedIndex = index + 1
            return "\(indent)\(index). \(content)\n\(nestedContent)"
        }
        return "\(indent)- \(content)\n\(nestedContent)"
    }

    private static func removingLeadingCheckbox(from content: String) -> String {
        var result = content.trimmingCharacters(in: .whitespaces)
        if result.hasPrefix("☑") || result.hasPrefix("☐") {
            result.removeFirst()
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Tables

    private static func convertTable(_ table: Element) -> String {
        var headerRows: [[String]] = []
        var bodyRows: [[String]] = []

        for child in table.children() {
            switch child.tagName().lowercased() {
            case "thead":
                headerRows.append(contentsOf: tableRows(in: child))
            case "tbody", "tfoot":
                bodyRows.append(contentsOf: tableRows(in: child))
            case "tr":
                if let row = tableRow(child) {
                    bodyRows.append(row)
                }
            default:
                continue
            }
        }

        let rows = headerRows + bodyRows
        guard !rows.isEmpty else { return "" }

        let columnCount = rows.map(\.count).max() ?? 0
        guard columnCount > 0 else { return "" }

        let normalizedRows = rows.map { row -> [String] in
            row + [String](repeating: "", count: columnCount - row.count)
        }

        func formattedRow(_ cells: [String]) -> String {
            "| " + cells.joined(separator: " | ") + " |"
        }

        var lines = [formattedRow(normalizedRows[0])]
        lines.append("| " + [String](repeating: "---", count: columnCount).joined(separator: " | ") + " |")
        lines.append(contentsOf: normalizedRows.dropFirst().map(formattedRow))
        return lines.joined(separator: "\n") + "\n\n"
    }

    private static func tableRows(in section: Element) -> [[String]] {
        section.children().compactMap { child in
            child.tagName().lowercased() == "tr" ? tableRow(child) : nil
        }
    }

    private static func tableRow(_ row: Element) -> [String]? {
        let cells = row.children().filter {
            let tag = $0.tagName().lowercased()
            return tag == "th" || tag == "td"
        }
        guard !cells.isEmpty else { return nil }
        return cells.map(tableCell)
    }

    private static func tableCell(_ cell: Element) -> String {
        let markdown = convertChildren(
            cell,
            listDepth: 0,
            inPre: false,
            startsAtLineStart: false
        )
        return markdown
            .replacingOccurrences(
                of: #"[ \t]*(?:\r\n|\r|\n)+[ \t]*"#,
                with: "<br>",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "|", with: #"\|"#)
    }

    // MARK: - Text and code

    private static func convertChildren(
        _ element: Element,
        listDepth: Int,
        inPre: Bool,
        startsAtLineStart: Bool
    ) -> String {
        var result = ""
        for child in element.getChildNodes() {
            result += convertNode(
                child,
                listDepth: listDepth,
                inPre: inPre,
                startsAtLineStart: isAtLineStart(in: result, initial: startsAtLineStart)
            )
        }
        return result
    }

    private static func isAtLineStart(in output: String, initial: Bool) -> Bool {
        guard !output.isEmpty else { return initial }
        let suffix: Substring
        if let newline = output.lastIndex(of: "\n") {
            suffix = output[output.index(after: newline)...]
        } else {
            guard initial else { return false }
            suffix = output[...]
        }
        return suffix.allSatisfy { $0 == " " || $0 == "\t" }
    }

    private static func escapeMarkdownText(_ text: String, startsAtLineStart: Bool) -> String {
        let lines = text.components(separatedBy: "\n")
        return lines.enumerated().map { offset, line in
            let marker = blockMarkerIndex(
                in: line,
                enabled: startsAtLineStart || offset > 0
            )
            var result = ""
            for index in line.indices {
                let character = line[index]
                if index == marker || markdownInlineMetacharacters.contains(character) {
                    result.append("\\")
                }
                result.append(character)
            }
            return result
        }.joined(separator: "\n")
    }

    private static let markdownInlineMetacharacters: Set<Character> = [
        "\\", "*", "_", "[", "]", "(", ")", "`", "~", "<", "&",
    ]

    private static func blockMarkerIndex(in line: String, enabled: Bool) -> String.Index? {
        guard enabled else { return nil }
        let patterns = [
            #"^\s{0,3}(#{1,6})(?:[ \t]+|$)"#,
            #"^\s{0,3}(>)(?:[ \t]+|$)"#,
            #"^\s{0,3}([-+])(?:[ \t]+|$)"#,
            #"^\s{0,3}\d{1,9}([.)])(?:[ \t]+|$)"#,
            #"^\s{0,3}([-=_])(?:[ \t]*\1){2,}[ \t]*$"#,
        ]

        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern),
                  let match = expression.firstMatch(
                      in: line,
                      range: NSRange(line.startIndex..., in: line)
                  ),
                  let range = Range(match.range(at: 1), in: line) else {
                continue
            }
            return range.lowerBound
        }
        return nil
    }

    private static func preservingWhitespaceText(_ element: Element) -> String {
        element.getChildNodes().map { child in
            if let textNode = child as? TextNode {
                return textNode.getWholeText()
            }
            if let childElement = child as? Element {
                if childElement.tagName().lowercased() == "br" {
                    return "\n"
                }
                return preservingWhitespaceText(childElement)
            }
            return ""
        }.joined()
    }

    private static func inlineCode(_ text: String) -> String {
        let delimiter = String(
            repeating: "`",
            count: max(1, longestRun(of: "`", in: text) + 1)
        )
        let needsPadding = text.hasPrefix("`")
            || text.hasSuffix("`")
            || text.hasPrefix(" ")
            || text.hasSuffix(" ")
        let padding = needsPadding ? " " : ""
        return "\(delimiter)\(padding)\(text)\(padding)\(delimiter)"
    }

    private static func longestRun(of character: Character, in text: String) -> Int {
        var longest = 0
        var current = 0
        for value in text {
            if value == character {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }

    private static func codeLanguage(from element: Element) -> String? {
        guard let classNames = try? element.classNames() else { return nil }
        for className in classNames where className.hasPrefix("language-") {
            let language = String(className.dropFirst("language-".count))
            if isSafeLanguage(language) {
                return language
            }
        }
        return nil
    }

    private static func isSafeLanguage(_ language: String) -> Bool {
        !language.isEmpty
            && language.range(
                of: #"^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$"#,
                options: .regularExpression
            ) != nil
    }

    // MARK: - Links and styles

    private static func markdownDestination(_ value: String, forImage: Bool) -> String? {
        guard let safeValue = safeURL(value, forImage: forImage) else { return nil }
        return safeValue
            .replacingOccurrences(of: "\\", with: "%5C")
            .replacingOccurrences(of: "(", with: "%28")
            .replacingOccurrences(of: ")", with: "%29")
            .replacingOccurrences(of: "<", with: "%3C")
            .replacingOccurrences(of: ">", with: "%3E")
    }

    private static func safeURL(_ value: String, forImage: Bool) -> String? {
        guard !value.isEmpty,
              value.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
                      && !CharacterSet.whitespacesAndNewlines.contains($0)
              }),
              let components = URLComponents(string: value) else {
            return nil
        }

        guard let scheme = components.scheme?.lowercased() else {
            return forImage || value.hasPrefix("//") ? nil : value
        }
        if forImage {
            return ["http", "https"].contains(scheme) && components.host != nil ? value : nil
        }
        return ["http", "https", "mailto", "tel"].contains(scheme) ? value : nil
    }

    private static func applyInlineStyle(to content: String, style: String) -> String {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return content
        }
        let normalizedStyle = style.lowercased()
        var result = content
        if normalizedStyle.range(
            of: #"font-weight\s*:\s*(bold|[6-9]00)"#,
            options: .regularExpression
        ) != nil {
            result = "**\(result)**"
        }
        if normalizedStyle.range(
            of: #"font-style\s*:\s*italic"#,
            options: .regularExpression
        ) != nil {
            result = "*\(result)*"
        }
        if normalizedStyle.range(
            of: #"text-decoration[^;]*line-through"#,
            options: .regularExpression
        ) != nil {
            result = "~~\(result)~~"
        }
        return result
    }

    // MARK: - Output normalization

    private static func normalizeMarkdown(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var output: [String] = []
        var activeFence: String?
        var previousWasBlank = false

        for line in trimmed.components(separatedBy: "\n") {
            let whitespaceTrimmed = line.trimmingCharacters(in: .whitespaces)

            if let fence = activeFence {
                output.append(line)
                if whitespaceTrimmed == fence {
                    activeFence = nil
                }
                continue
            }

            if let fence = openingFence(in: whitespaceTrimmed) {
                output.append(line)
                activeFence = fence
                previousWasBlank = false
                continue
            }

            if whitespaceTrimmed.isEmpty {
                if !previousWasBlank {
                    output.append("")
                    previousWasBlank = true
                }
            } else {
                output.append(line)
                previousWasBlank = false
            }
        }

        return output.joined(separator: "\n")
    }

    private static func openingFence(in line: String) -> String? {
        guard line.first == "`" else { return nil }
        let count = line.prefix(while: { $0 == "`" }).count
        guard count >= 3 else { return nil }
        let fence = String(repeating: "`", count: count)
        let metadata = line.dropFirst(count)
        return metadata.contains("`") ? nil : fence
    }
}
