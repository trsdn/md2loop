import AppKit
import XCTest
@testable import md2loop

final class ClipboardConversionServiceTests: XCTestCase {

    func testConversionUsesOneFreshSnapshotInsteadOfCachedDisplayValue() throws {
        let cachedValue = ClipboardSnapshot(
            changeCount: 10,
            text: "# Old",
            html: nil,
            rtfData: nil
        )
        XCTAssertEqual(cachedValue.mode, .markdown)

        let clipboard = FakeClipboard(
            snapshot: ClipboardSnapshot(
                changeCount: 11,
                text: "# New",
                html: nil,
                rtfData: nil
            )
        )

        let result = try ClipboardConversionService(clipboard: clipboard).convertCurrentSnapshot()

        XCTAssertEqual(result, ClipboardConversionResult(action: .toLoop, sourceChangeCount: 11))
        XCTAssertEqual(clipboard.readCount, 1)
        XCTAssertEqual(
            clipboard.writes,
            [.loop(html: "<h1>New</h1>", markdown: "# New")]
        )
    }

    func testDetectionAndConversionUseTheSameMixedFormatSnapshot() throws {
        let clipboard = FakeClipboard(
            snapshot: ClipboardSnapshot(
                changeCount: 21,
                text: "# Title\n\n**bold**",
                html: """
                <pre><span class="token"># Title

                **bold**</span></pre>
                """,
                rtfData: nil
            )
        )

        let result = try ClipboardConversionService(clipboard: clipboard).convertCurrentSnapshot()

        XCTAssertEqual(result.action, .toLoop)
        XCTAssertEqual(clipboard.readCount, 1)
        XCTAssertEqual(
            clipboard.writes,
            [
                .loop(
                    html: "<h1>Title</h1><p><strong>bold</strong></p>",
                    markdown: "# Title\n\n**bold**"
                ),
            ]
        )
    }

    func testRichTextConversionUsesHTMLFromTheFreshSnapshot() throws {
        let clipboard = FakeClipboard(
            snapshot: ClipboardSnapshot(
                changeCount: 31,
                text: "Hello world",
                html: "<p>Hello <strong>world</strong></p>",
                rtfData: nil
            )
        )

        let result = try ClipboardConversionService(clipboard: clipboard).convertCurrentSnapshot()

        XCTAssertEqual(
            result,
            ClipboardConversionResult(action: .toMarkdown, sourceChangeCount: 31)
        )
        XCTAssertEqual(clipboard.readCount, 1)
        XCTAssertEqual(clipboard.writes, [.markdown("Hello **world**")])
    }

    func testExplicitLoopActionOverridesRichTextDetection() throws {
        let clipboard = FakeClipboard(
            snapshot: ClipboardSnapshot(
                changeCount: 35,
                text: "# Source",
                html: "<h1>Rendered</h1>",
                rtfData: nil
            )
        )
        XCTAssertEqual(clipboard.snapshot.mode, .richText)

        let result = try ClipboardConversionService(clipboard: clipboard)
            .convertCurrentSnapshot(using: .toLoop)

        XCTAssertEqual(result.action, .toLoop)
        XCTAssertEqual(
            clipboard.writes,
            [.loop(html: "<h1>Source</h1>", markdown: "# Source")]
        )
    }

    func testExplicitMarkdownActionOverridesMarkdownDetection() throws {
        let clipboard = FakeClipboard(
            snapshot: ClipboardSnapshot(
                changeCount: 36,
                text: "# Source",
                html: "<span>Rendered</span>",
                rtfData: nil
            )
        )
        XCTAssertEqual(clipboard.snapshot.mode, .markdown)

        let result = try ClipboardConversionService(clipboard: clipboard)
            .convertCurrentSnapshot(using: .toMarkdown)

        XCTAssertEqual(result.action, .toMarkdown)
        XCTAssertEqual(clipboard.writes, [.markdown("Rendered")])
    }

    func testExplicitActionReportsMissingRepresentation() {
        let clipboard = FakeClipboard(
            snapshot: ClipboardSnapshot(
                changeCount: 37,
                text: nil,
                html: "<p>Rendered</p>",
                rtfData: nil
            )
        )

        XCTAssertThrowsError(
            try ClipboardConversionService(clipboard: clipboard)
                .convertCurrentSnapshot(using: .toLoop)
        ) { error in
            XCTAssertEqual(error as? ClipboardConversionError, .plainTextUnavailable)
        }
        XCTAssertEqual(clipboard.writes, [])
    }

    func testFailedFreshReadNeverWritesCachedOrReplacementContent() {
        let clipboard = FakeClipboard(
            snapshot: ClipboardSnapshot(
                changeCount: 40,
                text: "# Ignored",
                html: nil,
                rtfData: nil
            )
        )
        clipboard.readError = ClipboardAccessError.changedDuringRead

        XCTAssertThrowsError(
            try ClipboardConversionService(clipboard: clipboard).convertCurrentSnapshot()
        ) { error in
            XCTAssertEqual(error as? ClipboardAccessError, .changedDuringRead)
        }
        XCTAssertEqual(clipboard.readCount, 1)
        XCTAssertEqual(clipboard.writes, [])
    }

    func testMarkdownWriteFailureIsSurfaced() {
        let clipboard = FakeClipboard(
            snapshot: ClipboardSnapshot(
                changeCount: 50,
                text: "# Current",
                html: nil,
                rtfData: nil
            )
        )
        clipboard.writeError = ClipboardAccessError.writeFailed

        XCTAssertThrowsError(
            try ClipboardConversionService(clipboard: clipboard).convertCurrentSnapshot()
        ) { error in
            XCTAssertEqual(error as? ClipboardAccessError, .writeFailed)
        }
        XCTAssertEqual(clipboard.readCount, 1)
        XCTAssertEqual(clipboard.writes, [])
    }

    func testRichTextWriteFailureIsSurfaced() {
        let clipboard = FakeClipboard(
            snapshot: ClipboardSnapshot(
                changeCount: 60,
                text: "Hello",
                html: "<p>Hello</p>",
                rtfData: nil
            )
        )
        clipboard.writeError = ClipboardAccessError.writeFailed

        XCTAssertThrowsError(
            try ClipboardConversionService(clipboard: clipboard).convertCurrentSnapshot()
        ) { error in
            XCTAssertEqual(error as? ClipboardAccessError, .writeFailed)
        }
        XCTAssertEqual(clipboard.readCount, 1)
        XCTAssertEqual(clipboard.writes, [])
    }

    func testSystemClipboardWritesReadablePreparedRepresentations() throws {
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("md2loop-tests-\(UUID().uuidString)")
        )
        defer { pasteboard.clearContents() }

        let clipboard = SystemClipboard(pasteboard: pasteboard)
        try clipboard.writeForLoop(
            html: "<p>Hello <strong>world</strong></p>",
            markdown: "Hello **world**"
        )

        let richSnapshot = try clipboard.readSnapshot()
        XCTAssertEqual(richSnapshot.text, "Hello **world**")
        XCTAssertEqual(richSnapshot.html, "<p>Hello <strong>world</strong></p>")
        XCTAssertNotNil(richSnapshot.rtfData)

        try clipboard.writeMarkdown("# Plain")

        let markdownSnapshot = try clipboard.readSnapshot()
        XCTAssertEqual(markdownSnapshot.text, "# Plain")
        XCTAssertNil(markdownSnapshot.html)
        XCTAssertNil(markdownSnapshot.rtfData)
    }
}

private final class FakeClipboard: ClipboardAccessing {
    enum Write: Equatable {
        case loop(html: String, markdown: String)
        case markdown(String)
    }

    var snapshot: ClipboardSnapshot
    var readError: Error?
    var writeError: Error?
    private(set) var readCount = 0
    private(set) var writes: [Write] = []

    init(snapshot: ClipboardSnapshot) {
        self.snapshot = snapshot
    }

    func readSnapshot() throws -> ClipboardSnapshot {
        readCount += 1
        if let readError {
            throw readError
        }
        return snapshot
    }

    func writeForLoop(html: String, markdown: String) throws {
        if let writeError {
            throw writeError
        }
        writes.append(.loop(html: html, markdown: markdown))
    }

    func writeMarkdown(_ markdown: String) throws {
        if let writeError {
            throw writeError
        }
        writes.append(.markdown(markdown))
    }
}
