import XCTest
@testable import md2loop

final class ClipboardContentDetectorTests: XCTestCase {

    func testDetectsSingleMarkdownSignals() {
        XCTAssertEqual(ClipboardContentDetector.mode(text: "- Item", html: nil, rtfData: nil), .markdown)
        XCTAssertEqual(ClipboardContentDetector.mode(text: "1. Item", html: nil, rtfData: nil), .markdown)
        XCTAssertEqual(ClipboardContentDetector.mode(text: "**Important**", html: nil, rtfData: nil), .markdown)
        XCTAssertEqual(ClipboardContentDetector.mode(text: "Use `code` here", html: nil, rtfData: nil), .markdown)
    }

    func testLeavesPlainTextUnknown() {
        XCTAssertEqual(ClipboardContentDetector.mode(text: "Just a normal sentence.", html: nil, rtfData: nil), .unknown)
    }

    func testRichTextWinsOverPlainStringFallback() {
        XCTAssertEqual(
            ClipboardContentDetector.mode(text: "Title\nBody", html: "<h1>Title</h1><p>Body</p>", rtfData: nil),
            .richText
        )
        XCTAssertEqual(
            ClipboardContentDetector.mode(text: "Title", html: nil, rtfData: Data(#"{\rtf1\ansi Title}"#.utf8)),
            .richText
        )
    }
}
