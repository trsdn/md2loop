import Markdown

struct LoopHTMLConverter: MarkupVisitor {
    typealias Result = String

    private var inTableHead = false

    static func convert(_ markdown: String) -> String {
        var converter = LoopHTMLConverter()
        let document = Document(parsing: markdown)
        return converter.visit(document)
    }

    // MARK: - Block visitors

    mutating func defaultVisit(_ markup: Markup) -> String {
        markup.children.map { visit($0) }.joined()
    }

    mutating func visitDocument(_ document: Document) -> String {
        document.children.map { visit($0) }.joined()
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let level = min(heading.level, 3)
        let content = heading.children.map { visit($0) }.joined()
        return "<h\(level)>\(content)</h\(level)>"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        let content = paragraph.children.map { visit($0) }.joined()
        return "<p>\(content)</p>"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        let content = blockQuote.children.map { visit($0) }.joined()
        return "<blockquote>\(content)</blockquote>"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let escaped = escapeHTML(codeBlock.code)
        if let lang = codeBlock.language, !lang.isEmpty {
            return "<pre><code>// \(escapeHTML(lang))\n\(escaped)</code></pre>"
        }
        return "<pre><code>\(escaped)</code></pre>"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr>"
    }

    // MARK: - List visitors

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        let content = unorderedList.children.map { visit($0) }.joined()
        return "<ul>\(content)</ul>"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        let content = orderedList.children.map { visit($0) }.joined()
        return "<ol>\(content)</ol>"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        let content = listItem.children.map { visit($0) }.joined()
        if let checkbox = listItem.checkbox {
            let symbol = checkbox == .checked ? "☑ " : "☐ "
            return "<li>\(symbol)\(content)</li>"
        }
        return "<li>\(content)</li>"
    }

    // MARK: - Table visitors

    mutating func visitTable(_ table: Table) -> String {
        let content = table.children.map { visit($0) }.joined()
        return "<table>\(content)</table>"
    }

    mutating func visitTableHead(_ tableHead: Table.Head) -> String {
        inTableHead = true
        let cells = tableHead.children.map { visit($0) }.joined()
        inTableHead = false
        return "<tr>\(cells)</tr>"
    }

    mutating func visitTableBody(_ tableBody: Table.Body) -> String {
        tableBody.children.map { visit($0) }.joined()
    }

    mutating func visitTableRow(_ tableRow: Table.Row) -> String {
        let cells = tableRow.children.map { visit($0) }.joined()
        return "<tr>\(cells)</tr>"
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) -> String {
        let content = tableCell.children.map { visit($0) }.joined()
        if inTableHead {
            return "<th>\(content)</th>"
        }
        return "<td>\(content)</td>"
    }

    // MARK: - Inline visitors

    mutating func visitText(_ text: Text) -> String {
        escapeHTML(text.string)
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        let content = strong.children.map { visit($0) }.joined()
        return "<strong>\(content)</strong>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        let content = emphasis.children.map { visit($0) }.joined()
        return "<em>\(content)</em>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        let content = strikethrough.children.map { visit($0) }.joined()
        return "<s>\(content)</s>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(escapeHTML(inlineCode.code))</code>"
    }

    mutating func visitLink(_ link: Link) -> String {
        let content = link.children.map { visit($0) }.joined()
        let href = link.destination ?? ""
        return "<a href=\"\(escapeHTML(href))\">\(content)</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let alt = image.plainText
        let url = image.source ?? ""
        return "<a href=\"\(escapeHTML(url))\">[Bild: \(escapeHTML(alt))]</a>"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br>"
    }

    // MARK: - Helpers

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
