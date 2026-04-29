import AppKit
import XCTest
@testable import md2loop

final class ConversionTests: XCTestCase {

    func testMarkdownHTMLMarkdownRoundTripKeepsCoreStructure() {
        let markdown = """
        # Title

        A paragraph with **bold**, *italic*, and [link](https://example.com).

        - [x] Done
        - [ ] Todo

        | Name | Value |
        | ---- | ----- |
        | A    | B     |

        ```swift
        let value = 1
        ```
        """

        let html = LoopHTMLConverter.convert(markdown)
        let roundTripped = HTMLToMarkdownConverter.convert(html)

        XCTAssertTrue(roundTripped.contains("# Title"))
        XCTAssertTrue(roundTripped.contains("**bold**"))
        XCTAssertTrue(roundTripped.contains("*italic*"))
        XCTAssertTrue(roundTripped.contains("[link](https://example.com)"))
        XCTAssertTrue(roundTripped.contains("- [x] Done"))
        XCTAssertTrue(roundTripped.contains("- [ ] Todo"))
        XCTAssertTrue(roundTripped.contains("| Name"))
        XCTAssertTrue(roundTripped.contains("let value = 1"))
    }

    func testHTMLNestedListsBecomeNestedMarkdownLists() {
        let html = "<ul><li>Parent<ul><li>Child</li></ul></li></ul>"

        XCTAssertEqual(HTMLToMarkdownConverter.convert(html), "- Parent\n    - Child")
    }

    func testRTFConvertsThroughMarkdownFallback() throws {
        let html = "<p>Hello <strong>bold</strong></p>"
        let attributedString = NSAttributedString(html: Data(html.utf8), documentAttributes: nil)
        let unwrapped = try XCTUnwrap(attributedString)
        let range = NSRange(location: 0, length: unwrapped.length)
        let rtfData = try XCTUnwrap(unwrapped.rtf(from: range, documentAttributes: [:]))

        let markdown = RichTextToMarkdownConverter.convertRTF(rtfData)

        XCTAssertTrue(markdown.contains("Hello"))
        XCTAssertTrue(markdown.contains("**bold**"))
    }
}
