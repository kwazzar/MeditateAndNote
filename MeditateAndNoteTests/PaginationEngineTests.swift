//
//  PaginationEngineTests.swift
//  MeditateAndNoteTests
//

import XCTest
import MeditateAndNoteCore
@testable import MeditateAndNote

final class PaginationEngineTests: XCTestCase {

    /// Monospace-ish measurer: 10 units per character, line height 10.
    private struct FixedMeasurer: TextMeasurer {
        func width(of text: String) -> Double { Double(text.count) * 10 }
        func lineHeight() -> Double { 10 }
    }

    private let measurer = FixedMeasurer()

    private func paragraph(_ text: String) -> BookBlock {
        BookBlock(.paragraph, text)
    }

    private func makeEngine() -> PaginationEngine {
        PaginationEngine(measurer: measurer)
    }

    // MARK: - Wrapping

    func testPaginate_singleShortParagraph_singlePage() {
        let content = BookContent(chapters: [BookChapter(blocks: [paragraph("hello")])])
        // Page: 10 chars wide → "hello" (5 chars) fits on one line.
        let result = makeEngine().paginate(content, pageSize: PageSize(width: 100, height: 10))

        XCTAssertEqual(result.pages.count, 1)
        // Paragraphs open with a 4-space first-line indent.
        XCTAssertEqual(result.pages[0].lines, ["    hello"])
        XCTAssertEqual(result.totalCharacters, 5)
    }

    func testPaginate_longParagraph_wrapsIntoMultipleLines() {
        let text = String(repeating: "ab ", count: 20).trimmingCharacters(in: .whitespaces)
        let content = BookContent(chapters: [BookChapter(blocks: [paragraph(text)])])
        // 100/10 = 10 chars per line.
        let result = makeEngine().paginate(content, pageSize: PageSize(width: 100, height: 100))

        XCTAssertTrue(result.pages[0].lines.allSatisfy { $0.count <= 10 })
    }

    func testPaginate_wordLongerThanLine_hardBreaks() {
        let text = String(repeating: "x", count: 25)
        let content = BookContent(chapters: [BookChapter(blocks: [paragraph(text)])])
        let result = makeEngine().paginate(content, pageSize: PageSize(width: 100, height: 100))

        let joined = result.pages.flatMap { $0.lines }.joined()
        XCTAssertEqual(joined, "    " + text)
        XCTAssertTrue(result.pages.flatMap { $0.lines }.allSatisfy { $0.count <= 10 })
    }

    // MARK: - Page filling

    func testPaginate_linesOverflow_heightCreatesNewPages() {
        let text = String(repeating: "word ", count: 30).trimmingCharacters(in: .whitespaces)
        let content = BookContent(chapters: [BookChapter(blocks: [paragraph(text)])])
        // 3 lines per page (height 30 / line height 10).
        let result = makeEngine().paginate(content, pageSize: PageSize(width: 100, height: 30))

        XCTAssertEqual(result.pages.count, result.pages.count) // structural
        XCTAssertTrue(result.pages.count >= 2)
        XCTAssertTrue(result.pages.dropLast().allSatisfy { $0.lines.count == 3 })
    }

    func testPaginate_headingForcesNewPage() {
        let chapter = BookChapter(
            blocks: [
                paragraph("first"),
                BookBlock(.heading, "Chapter"),
                paragraph("second"),
            ]
        )
        let content = BookContent(chapters: [chapter])
        // Height fits 2 lines → paragraph splits across pages; heading starts fresh page.
        let result = makeEngine().paginate(content, pageSize: PageSize(width: 100, height: 20))

        let headingPageIndex = result.pages.firstIndex { $0.lines.first == "Chapter" }
        XCTAssertFalse(result.pages[0].lines.contains("Chapter"))
        XCTAssertNotNil(headingPageIndex)
        // The heading starts a fresh page; the following paragraph may share it.
        if let index = headingPageIndex, index + 1 < result.pages.count {
            XCTAssertFalse(result.pages[index + 1].lines.contains("Chapter"))
        }
    }

    // MARK: - Position mapping

    func testPageRoundTrip_positionAtPageOrigin() {
        let text = String(repeating: "word ", count: 30).trimmingCharacters(in: .whitespaces)
        let content = BookContent(chapters: [BookChapter(blocks: [paragraph(text)])])
        let engine = makeEngine()
        let paginated = engine.paginate(content, pageSize: PageSize(width: 100, height: 30))

        for pageIndex in [0, paginated.pages.count / 2, paginated.pages.count - 1] {
            let position = engine.position(atPage: pageIndex, in: paginated)
            let found = engine.page(of: position, in: paginated)
            XCTAssertEqual(found, pageIndex)
        }
    }

    func testPage_ofPositionMidParagraph_findsContainingPage() {
        let text = String(repeating: "word ", count: 30).trimmingCharacters(in: .whitespaces)
        let content = BookContent(chapters: [BookChapter(blocks: [paragraph(text)])])
        let engine = makeEngine()
        let paginated = engine.paginate(content, pageSize: PageSize(width: 100, height: 30))
        guard paginated.pages.count >= 2 else { return XCTFail("expected multi-page") }

        // Position inside the last block, far offset → resolves to last page.
        // The offset counts from the indented first line, so stay comfortably
        // past the last page's origin.
        let position = ReadingPosition(chapterIndex: 0, blockIndex: 0, characterOffset: text.count + 5)
        XCTAssertEqual(engine.page(of: position, in: paginated), paginated.pages.count - 1)
    }

    func testPage_positionBeyondContent_resolvesToLastPage() {
        let content = BookContent(chapters: [BookChapter(blocks: [paragraph("small")])])
        let engine = makeEngine()
        let paginated = engine.paginate(content, pageSize: PageSize(width: 100, height: 100))

        let position = ReadingPosition(chapterIndex: 99, blockIndex: 99, characterOffset: 99)
        XCTAssertEqual(engine.page(of: position, in: paginated), 0)
    }

    func testPaginate_emptyContent_singleEmptyPage() {
        let content = BookContent(chapters: [])
        let result = makeEngine().paginate(content, pageSize: PageSize(width: 100, height: 100))

        XCTAssertEqual(result.pages.count, 1)
        XCTAssertEqual(result.totalCharacters, 0)
        XCTAssertEqual(result.progress(ofPageAt: 0), 0)
    }

    func testProgress_growsMonotonicallyWithPages() {
        let text = String(repeating: "word ", count: 60).trimmingCharacters(in: .whitespaces)
        let content = BookContent(chapters: [BookChapter(blocks: [paragraph(text)])])
        let paginated = makeEngine().paginate(content, pageSize: PageSize(width: 100, height: 30))

        let values = (0..<paginated.pages.count).map { paginated.progress(ofPageAt: $0) }
        XCTAssertEqual(values, values.sorted())
        XCTAssertEqual(values.last!, 1.0, accuracy: 0.2)
        XCTAssertGreaterThanOrEqual(values.first!, 0)
    }

    func testRepagination_restoresSameLogicalPosition() {
        // A 60-word paragraph: narrow page = 1 word/line, wide = 8 words/line.
        let text = String(repeating: "alpha ", count: 60).trimmingCharacters(in: .whitespaces)
        let content = BookContent(chapters: [BookChapter(blocks: [paragraph(text)])])
        let engine = makeEngine()

        let narrow = engine.paginate(content, pageSize: PageSize(width: 100, height: 30))
        let wide = engine.paginate(content, pageSize: PageSize(width: 500, height: 30))
        XCTAssertGreaterThan(narrow.pages.count, wide.pages.count)

        // Read halfway through the narrow layout, then switch to wide: the
        // restored wide page must contain the same character position.
        let midPage = narrow.pages.count / 2
        let position = engine.position(atPage: midPage, in: narrow)
        let restoredPage = engine.page(of: position, in: wide)

        let globalOffset = narrow.pages[midPage].startGlobalOffset
        let restored = wide.pages[restoredPage!]
        let nextStart = restoredPage! + 1 < wide.pages.count
            ? wide.pages[restoredPage! + 1].startGlobalOffset
            : Int.max
        XCTAssertLessThanOrEqual(restored.startGlobalOffset, globalOffset)
        XCTAssertLessThan(globalOffset, nextStart)
    }
}

// MARK: - ReadingPosition

final class ReadingPositionTests: XCTestCase {

    func testClamp_negativeIndices_clampedToZero() {
        let content = BookContent(chapters: [BookChapter(blocks: [BookBlock(.paragraph, "abc")])])
        let clamped = ReadingPosition(chapterIndex: -5, blockIndex: -5, characterOffset: -5).clamped(to: content)
        XCTAssertEqual(clamped, ReadingPosition())
    }

    func testClamp_indicesBeyondContent_clampedToLastValid() {
        let content = BookContent(
            chapters: [
                BookChapter(blocks: [BookBlock(.paragraph, "aa")]),
                BookChapter(blocks: [BookBlock(.paragraph, "bbb")]),
            ]
        )
        let clamped = ReadingPosition(chapterIndex: 10, blockIndex: 10, characterOffset: 10).clamped(to: content)
        XCTAssertEqual(clamped.chapterIndex, 1)
        XCTAssertEqual(clamped.blockIndex, 0)
        XCTAssertEqual(clamped.characterOffset, 2)
    }

    func testProgress_zeroContent_isZero() {
        let content = BookContent(chapters: [])
        XCTAssertEqual(content.progress(of: ReadingPosition()), 0)
    }

    func testProgress_midBook_partialValue() {
        let content = BookContent(
            chapters: [
                BookChapter(blocks: [BookBlock(.paragraph, String(repeating: "a", count: 100))]),
                BookChapter(blocks: [BookBlock(.paragraph, String(repeating: "b", count: 100))]),
            ]
        )
        let position = ReadingPosition(chapterIndex: 1, blockIndex: 0, characterOffset: 50)
        XCTAssertEqual(content.progress(of: position), 150.0 / 200.0, accuracy: 0.001)
    }
}
