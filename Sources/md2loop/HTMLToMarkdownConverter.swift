import Foundation
import SwiftSoup

struct HTMLToMarkdownConverter {

    static func convert(_ html: String) -> String {
        guard !html.isEmpty else { return "" }
        do {
            let doc = try SwiftSoup.parse(html)
            guard let body = doc.body() else { return "" }
            var orderedIndex: Int? = nil
            let raw = body.getChildNodes().map { convertNode($0, listDepth: 0, orderedIndex: &orderedIndex, inPre: false) }.joined()
            // Trim and collapse excessive newlines
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let collapsed = trimmed.replacingOccurrences(
                of: "\\n{3,}", with: "\n\n", options: .regularExpression
            )
            return collapsed
        } catch {
            return ""
        }
    }

    // MARK: - Recursive node conversion

    private static func convertNode(_ node: Node, listDepth: Int, orderedIndex: inout Int?, inPre: Bool) -> String {
        if let textNode = node as? TextNode {
            if inPre {
                return textNode.getWholeText()
            }
            let text = textNode.getWholeText()
            // Collapse whitespace
            let collapsed = text.replacingOccurrences(
                of: "[\\s]+", with: " ", options: .regularExpression
            )
            return collapsed
        }

        guard let element = node as? Element else {
            return ""
        }

        let tag = element.tagName().lowercased()

        switch tag {

        // Headings
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(String(tag.last!))!
            let prefix = String(repeating: "#", count: level)
            let content = convertChildren(element, listDepth: listDepth, inPre: inPre)
                .trimmingCharacters(in: .whitespaces)
            return "\(prefix) \(content)\n\n"

        // Paragraphs
        case "p":
            let content = convertChildren(element, listDepth: listDepth, inPre: inPre)
                .trimmingCharacters(in: .whitespaces)
            return "\(content)\n\n"

        // Bold
        case "strong", "b":
            let content = convertChildren(element, listDepth: listDepth, inPre: inPre)
            return "**\(content)**"

        // Italic
        case "em", "i":
            let content = convertChildren(element, listDepth: listDepth, inPre: inPre)
            return "*\(content)*"

        // Strikethrough
        case "s", "del", "strike":
            let content = convertChildren(element, listDepth: listDepth, inPre: inPre)
            return "~~\(content)~~"

        // Inline code (not inside pre)
        case "code":
            if inPre {
                return convertChildren(element, listDepth: listDepth, inPre: true)
            }
            let text = (try? element.text()) ?? ""
            return "`\(text)`"

        // Pre/code blocks
        case "pre":
            let codeElement = try? element.select("code").first()
            let lang: String
            if let codeEl = codeElement,
               let cls = try? codeEl.className(),
               cls.contains("language-") {
                lang = cls.replacingOccurrences(
                    of: ".*language-(\\S+).*", with: "$1", options: .regularExpression
                )
            } else {
                lang = ""
            }
            let content: String
            if let codeEl = codeElement {
                content = (try? codeEl.text()) ?? ""
            } else {
                content = (try? element.text()) ?? ""
            }
            return "\n```\(lang)\n\(content)\n```\n\n"

        // Links
        case "a":
            let href = (try? element.attr("href")) ?? ""
            let content = convertChildren(element, listDepth: listDepth, inPre: inPre)
            return "[\(content)](\(href))"

        // Images
        case "img":
            let src = (try? element.attr("src")) ?? ""
            let alt = (try? element.attr("alt")) ?? ""
            return "![\(alt)](\(src))"

        // Unordered list
        case "ul":
            var result = ""
            for child in element.children() {
                guard child.tagName().lowercased() == "li" else { continue }
                var idx: Int? = nil
                result += convertListItem(child, listDepth: listDepth, orderedIndex: &idx, ordered: false)
            }
            return result

        // Ordered list
        case "ol":
            var result = ""
            var idx: Int? = 1
            for child in element.children() {
                guard child.tagName().lowercased() == "li" else { continue }
                result += convertListItem(child, listDepth: listDepth, orderedIndex: &idx, ordered: true)
            }
            return result

        // Table
        case "table":
            return convertTable(element)

        // Blockquote
        case "blockquote":
            let content = convertChildren(element, listDepth: listDepth, inPre: inPre)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lines = content.components(separatedBy: "\n")
            let quoted = lines.map { "> \($0)" }.joined(separator: "\n")
            return "\(quoted)\n\n"

        // Horizontal rule
        case "hr":
            return "\n---\n\n"

        // Line break
        case "br":
            return "\n"

        // Div
        case "div":
            let content = convertChildren(element, listDepth: listDepth, inPre: inPre)
            return "\(content)\n"

        // Default: transparent wrapper
        default:
            return convertChildren(element, listDepth: listDepth, inPre: inPre)
        }
    }

    // MARK: - Helpers

    private static func convertChildren(_ element: Element, listDepth: Int, inPre: Bool) -> String {
        var orderedIndex: Int? = nil
        return element.getChildNodes().map {
            convertNode($0, listDepth: listDepth, orderedIndex: &orderedIndex, inPre: inPre)
        }.joined()
    }

    private static func convertListItem(_ li: Element, listDepth: Int, orderedIndex: inout Int?, ordered: Bool) -> String {
        let indent = String(repeating: "    ", count: listDepth)

        // Check for task list
        let text = (try? li.text()) ?? ""
        let hasCheckedUnicode = text.contains("☑")
        let hasUncheckedUnicode = text.contains("☐")
        let checkedInput = (try? li.select("input[type=checkbox][checked]"))?.first() != nil
        let uncheckedInputEl = (try? li.select("input[type=checkbox]"))?.first()
        let hasUncheckedInput = uncheckedInputEl != nil && !checkedInput

        let content = convertChildren(li, listDepth: listDepth + 1, inPre: false)
            .trimmingCharacters(in: .whitespaces)

        if hasCheckedUnicode || checkedInput {
            let cleaned = content
                .replacingOccurrences(of: "☑", with: "")
                .trimmingCharacters(in: .whitespaces)
            return "\(indent)- [x] \(cleaned)\n"
        } else if hasUncheckedUnicode || hasUncheckedInput {
            let cleaned = content
                .replacingOccurrences(of: "☐", with: "")
                .trimmingCharacters(in: .whitespaces)
            return "\(indent)- [ ] \(cleaned)\n"
        } else if ordered, let idx = orderedIndex {
            orderedIndex = idx + 1
            return "\(indent)\(idx). \(content)\n"
        } else {
            return "\(indent)- \(content)\n"
        }
    }

    private static func convertTable(_ table: Element) -> String {
        var rows: [[String]] = []

        // Collect header rows
        if let thead = try? table.select("thead").first() {
            for tr in (try? thead.select("tr")) ?? Elements() {
                let cells = (try? tr.select("th, td")) ?? Elements()
                let row = cells.map { (try? $0.text()) ?? "" }
                rows.append(row)
            }
        }

        // Collect body rows
        let bodyRows: Elements
        if let tbody = try? table.select("tbody").first() {
            bodyRows = (try? tbody.select("tr")) ?? Elements()
        } else {
            bodyRows = (try? table.select("tr")) ?? Elements()
        }
        for tr in bodyRows {
            let cells = (try? tr.select("th, td")) ?? Elements()
            let row = cells.map { (try? $0.text()) ?? "" }
            if !row.isEmpty {
                rows.append(row)
            }
        }

        guard !rows.isEmpty else { return "" }

        // Determine column widths
        let colCount = rows.map(\.count).max() ?? 0
        var colWidths = [Int](repeating: 3, count: colCount)
        for row in rows {
            for (i, cell) in row.enumerated() where i < colCount {
                colWidths[i] = max(colWidths[i], cell.count)
            }
        }

        func formatRow(_ cells: [String]) -> String {
            var padded: [String] = []
            for i in 0..<colCount {
                let cell = i < cells.count ? cells[i] : ""
                padded.append(cell.padding(toLength: colWidths[i], withPad: " ", startingAt: 0))
            }
            return "| " + padded.joined(separator: " | ") + " |"
        }

        var result = ""
        // Header
        result += formatRow(rows[0]) + "\n"
        // Separator
        let sep = colWidths.map { String(repeating: "-", count: $0) }
        result += "| " + sep.joined(separator: " | ") + " |\n"
        // Body rows
        for row in rows.dropFirst() {
            result += formatRow(row) + "\n"
        }
        return result
    }
}
