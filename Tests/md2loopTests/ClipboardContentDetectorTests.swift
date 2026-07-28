import XCTest
@testable import md2loop

final class ClipboardContentDetectorTests: XCTestCase {

    func testNonemptyPlainTextIsMarkdownInput() {
        XCTAssertEqual(
            ClipboardContentDetector.mode(
                text: "Just a normal sentence.",
                html: nil,
                rtfData: nil
            ),
            .markdown
        )
        XCTAssertEqual(
            ClipboardContentDetector.mode(
                text: "Просто текст — 你好",
                html: nil,
                rtfData: nil
            ),
            .markdown
        )
    }

    func testEmptyAndWhitespaceOnlyTextRemainUnknown() {
        for text in [nil, "", " \t\r\n"] as [String?] {
            XCTAssertEqual(
                ClipboardContentDetector.mode(text: text, html: nil, rtfData: nil),
                .unknown
            )
        }
    }

    func testDetectsExplicitMarkdownSignals() {
        let samples = [
            "- Item",
            "1. Item",
            "**Important**",
            "Use `code` here",
            "Title\n=====",
            "| A | B |\n| --- | --- |",
        ]

        for sample in samples {
            XCTAssertEqual(
                ClipboardContentDetector.mode(text: sample, html: nil, rtfData: nil),
                .markdown,
                sample
            )
        }
    }

    func testSyntaxHighlightedMarkdownBeatsPresentationOnlyHTML() {
        let cases = [
            (
                "# Title",
                #"<pre><span class="token"># Title</span></pre>"#
            ),
            (
                "# Title\n\n**bold**",
                """
                <pre><span class="token"># Title

                **bold**</span></pre>
                """
            ),
        ]

        for (markdown, highlightedHTML) in cases {
            XCTAssertEqual(
                ClipboardContentDetector.mode(
                    text: markdown,
                    html: highlightedHTML,
                    rtfData: nil
                ),
                .markdown
            )
        }
    }

    func testSemanticRichHTMLRetainsPrecedence() {
        XCTAssertEqual(
            ClipboardContentDetector.mode(
                text: "# Title",
                html: "<h1>Title</h1>",
                rtfData: nil
            ),
            .richText
        )
        XCTAssertEqual(
            ClipboardContentDetector.mode(
                text: "- First\n- Second",
                html: "<ul><li>First</li><li>Second</li></ul>",
                rtfData: nil
            ),
            .richText
        )
        XCTAssertEqual(
            ClipboardContentDetector.mode(
                text: "```swift\nlet value = 1\n```",
                html: #"<pre><code class="language-swift">let value = 1</code></pre>"#,
                rtfData: nil
            ),
            .richText
        )
    }

    func testHTMLAndRTFOnlyContentAreRichText() {
        XCTAssertEqual(
            ClipboardContentDetector.mode(
                text: nil,
                html: "<p>Hello</p>",
                rtfData: nil
            ),
            .richText
        )
        XCTAssertEqual(
            ClipboardContentDetector.mode(
                text: "Plain fallback",
                html: nil,
                rtfData: Data(#"{\rtf1\ansi Title}"#.utf8)
            ),
            .richText
        )
    }
}
