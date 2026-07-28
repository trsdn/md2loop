import AppKit
import XCTest
@testable import md2loop

final class ConversionTests: XCTestCase {

    func testCoreMarkdownHTMLMarkdownRoundTripIsExact() {
        let markdown = """
        # Title

        A paragraph with **bold**, *italic*, and [link](https://example.com).
        """

        let html = LoopHTMLConverter.convert(markdown)
        let roundTripped = HTMLToMarkdownConverter.convert(html)

        XCTAssertEqual(
            html,
            #"<h1>Title</h1><p>A paragraph with <strong>bold</strong>, <em>italic</em>, and <a href="https://example.com">link</a>.</p>"#
        )
        XCTAssertEqual(roundTripped, markdown)
    }

    func testFencedCodeLanguageStaysMetadataAndNeverBecomesSource() {
        let cases: [(markdown: String, html: String)] = [
            (
                "```swift\nlet value = 1\n```",
                "<pre><code class=\"language-swift\">let value = 1\n</code></pre>"
            ),
            (
                "```json\n{\"value\": 1}\n```",
                "<pre><code class=\"language-json\">{&quot;value&quot;: 1}\n</code></pre>"
            ),
            (
                "```shell\nprintf '✓\\n'\n```",
                "<pre><code class=\"language-shell\">printf &#39;✓\\n&#39;\n</code></pre>"
            ),
            (
                "```\nlet π = \"你好\"\n```",
                "<pre><code>let π = &quot;你好&quot;\n</code></pre>"
            ),
        ]

        for testCase in cases {
            let html = LoopHTMLConverter.convert(testCase.markdown)
            XCTAssertEqual(html, testCase.html, testCase.markdown)
            XCTAssertEqual(
                HTMLToMarkdownConverter.convert(html),
                testCase.markdown,
                testCase.markdown
            )
        }
    }

    func testFencedCodeNormalizesCRLFWithoutChangingCodeLines() {
        let markdown = "```text\r\nfirst\r\nsecond\r\n```"
        let html = LoopHTMLConverter.convert(markdown)

        XCTAssertFalse(html.contains("// text"))
        XCTAssertEqual(
            HTMLToMarkdownConverter.convert(html),
            "```text\nfirst\nsecond\n```"
        )
    }

    func testLiteralMarkdownCharactersAreContextuallyEscaped() {
        let html = #"""
        <p># literal heading</p>
        <p>*literal* _under_ [label](dest) `code` \ path</p>
        <p>- list</p>
        <p>1. item</p>
        <p>&gt; quote</p>
        """#

        let markdown = HTMLToMarkdownConverter.convert(html)

        XCTAssertEqual(
            markdown,
            ##"""
            \# literal heading

            \*literal\* \_under\_ \[label\]\(dest\) \`code\` \\ path

            \- list

            1\. item

            \> quote
            """##
        )
        XCTAssertEqual(
            LoopHTMLConverter.convert(markdown),
            "<p># literal heading</p><p>*literal* _under_ [label](dest) `code` \\ path</p><p>- list</p><p>1. item</p><p>&gt; quote</p>"
        )
    }

    func testSemanticInlineHTMLStillProducesMarkdownSyntax() {
        let html = #"""
        <p><strong>bold</strong> <em>italic</em> <a href="https://example.com">link</a> <code>x*y</code></p>
        <ul><li>item</li></ul>
        """#

        XCTAssertEqual(
            HTMLToMarkdownConverter.convert(html),
            """
            **bold** *italic* [link](https://example.com) `x*y`

            - item
            """
        )
    }

    func testPreformattedContentIsNotEscapedOrWhitespaceCollapsed() {
        let html = "<pre><code>  # first\n\n*last*  \n</code></pre>"
        let markdown = "```\n  # first\n\n*last*  \n```"

        XCTAssertEqual(HTMLToMarkdownConverter.convert(html), markdown)
        XCTAssertEqual(
            LoopHTMLConverter.convert(markdown),
            "<pre><code>  # first\n\n*last*  \n</code></pre>"
        )
    }

    func testCodeFenceIsLongerThanEveryEmbeddedBacktickRun() {
        for runLength in 3...5 {
            let embeddedFence = String(repeating: "`", count: runLength)
            let outerFence = String(repeating: "`", count: runLength + 1)
            let code = "before\n\(embeddedFence)\nafter\n"
            let html = "<pre><code>\(code)</code></pre>"
            let expected = "\(outerFence)\nbefore\n\(embeddedFence)\nafter\n\(outerFence)"

            let markdown = HTMLToMarkdownConverter.convert(html)

            XCTAssertEqual(markdown, expected)
            XCTAssertEqual(LoopHTMLConverter.convert(markdown), html)
        }
    }

    func testEmptyAndLanguageTaggedCodeBlocksRemainValid() {
        XCTAssertEqual(
            HTMLToMarkdownConverter.convert("<pre><code></code></pre>"),
            "```\n```"
        )
        XCTAssertEqual(
            HTMLToMarkdownConverter.convert(
                #"""
                <pre><code class="token language-swift">let x = 1
                </code></pre>
                """#
            ),
            """
            ```swift
            let x = 1
            ```
            """
        )
    }

    func testTablePreservesFormattingEscapesCellsAndPadsUnevenRows() {
        let html = #"""
        <table>
          <thead><tr><th>Format</th><th>Path</th></tr></thead>
          <tr>
            <td><strong>x</strong> | <em>y</em></td>
            <td>C:\tmp<br><a href="https://example.com">link</a> <code>a|b</code></td>
            <td>extra</td>
          </tr>
          <tr><td>λ</td></tr>
        </table>
        """#

        XCTAssertEqual(
            HTMLToMarkdownConverter.convert(html),
            #"""
            | Format | Path |  |
            | --- | --- | --- |
            | **x** \| *y* | C:\\tmp<br>[link](https://example.com) `a\|b` | extra |
            | λ |  |  |
            """#
        )
    }

    func testTableHeaderRowsAreNeverDuplicated() {
        XCTAssertEqual(
            HTMLToMarkdownConverter.convert(
                "<table><thead><tr><th>A</th></tr></thead></table>"
            ),
            """
            | A |
            | --- |
            """
        )
        XCTAssertEqual(
            HTMLToMarkdownConverter.convert(
                "<table><thead><tr><th>A</th></tr><tr><th>B</th></tr></thead><tr><td>C</td></tr></table>"
            ),
            """
            | A |
            | --- |
            | B |
            | C |
            """
        )
    }

    func testMarkdownOrderedListStartsBecomeHTMLMetadata() {
        XCTAssertEqual(
            LoopHTMLConverter.convert("5. Five\n6. Six"),
            #"<ol start="5"><li><p>Five</p></li><li><p>Six</p></li></ol>"#
        )
        XCTAssertEqual(
            LoopHTMLConverter.convert("0. Zero\n1. One"),
            #"<ol start="0"><li><p>Zero</p></li><li><p>One</p></li></ol>"#
        )
        XCTAssertEqual(
            LoopHTMLConverter.convert(
                """
                5. Parent

                    3. Child
                    4. Next
                6. End
                """
            ),
            #"<ol start="5"><li><p>Parent</p><ol start="3"><li><p>Child</p></li><li><p>Next</p></li></ol></li><li><p>End</p></li></ol>"#
        )
    }

    func testHTMLOrderedListStartsRemainIndependentWhenNested() {
        XCTAssertEqual(
            HTMLToMarkdownConverter.convert(
                #"<ol start="5"><li>Five<ol start="3"><li>Three</li></ol></li><li>Six</li></ol>"#
            ),
            """
            5. Five
                3. Three
            6. Six
            """
        )
        XCTAssertEqual(
            HTMLToMarkdownConverter.convert(
                #"<ol start="0"><li>Zero</li><li>One</li></ol>"#
            ),
            """
            0. Zero
            1. One
            """
        )
        XCTAssertEqual(
            HTMLToMarkdownConverter.convert(
                #"<ol start="invalid"><li>One</li></ol>"#
            ),
            "1. One"
        )
    }

    func testMarkdownImagesUseSafeImageHTMLAndNeutralFallback() {
        XCTAssertEqual(
            LoopHTMLConverter.convert("![Cat](https://example.com/cat.png)"),
            #"<p><img src="https://example.com/cat.png" alt="Cat"></p>"#
        )
        XCTAssertEqual(
            LoopHTMLConverter.convert("![](https://example.com/cat.png)"),
            #"<p><img src="https://example.com/cat.png" alt=""></p>"#
        )
        XCTAssertEqual(
            LoopHTMLConverter.convert("![猫 & friend](https://example.com/cat.png?x=1&y=2)"),
            #"<p><img src="https://example.com/cat.png?x=1&amp;y=2" alt="猫 &amp; friend"></p>"#
        )
        XCTAssertEqual(
            LoopHTMLConverter.convert("![Unsafe](javascript:alert(1))"),
            #"<p><img alt="Unsafe"></p>"#
        )
    }

    func testHTMLImagesPreserveSafeSemanticsAndDropUnsafeDestinations() {
        XCTAssertEqual(
            HTMLToMarkdownConverter.convert(
                #"<p><img src="https://example.com/cat.png" alt="C[a]t"></p><p><img src="javascript:bad" alt="Bad"></p>"#
            ),
            #"""
            ![C\[a\]t](https://example.com/cat.png)

            ![Bad]()
            """#
        )
    }

    func testHTMLNestedListsBecomeNestedMarkdownLists() {
        XCTAssertEqual(
            HTMLToMarkdownConverter.convert(
                "<ul><li>Parent<ul><li>Child</li></ul></li></ul>"
            ),
            """
            - Parent
                - Child
            """
        )
    }

    func testRTFConvertsToExactMarkdown() throws {
        let html = "<p>Hello <strong>bold</strong></p>"
        let attributedString = try XCTUnwrap(
            NSAttributedString(html: Data(html.utf8), documentAttributes: nil)
        )
        let range = NSRange(location: 0, length: attributedString.length)
        let rtfData = try XCTUnwrap(
            attributedString.rtf(from: range, documentAttributes: [:])
        )

        XCTAssertEqual(
            RichTextToMarkdownConverter.convertRTF(rtfData),
            "Hello **bold**"
        )
    }
}
