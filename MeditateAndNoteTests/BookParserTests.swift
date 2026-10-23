//
//  BookParserTests.swift
//  MeditateAndNoteTests
//

import XCTest
import MeditateAndNoteCore
@testable import MeditateAndNote

final class BookParserTests: XCTestCase {

    // MARK: - FB2

    private let fb2Sample = """
    <?xml version="1.0" encoding="utf-8"?>
    <FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
      <description>
        <title-info>
          <book-title>Test Book</book-title>
          <author><first-name>Ivan</first-name><last-name>Petrov</last-name></author>
          <coverpage><image l:href="#cover.png"/></coverpage>
        </title-info>
      </description>
      <body>
        <section>
          <title><p>Chapter One</p></title>
          <p>First paragraph.</p>
          <p>Second paragraph with <emphasis>emphasis</emphasis>.</p>
          <section>
            <title><p>Nested</p></title>
            <p>Nested text.</p>
          </section>
        </section>
      </body>
      <binary id="cover.png" content-type="image/png">iVBORw0KGgo=</binary>
    </FictionBook>
    """

    func testFB2_extractsTitleAuthorChapters() throws {
        let result = try FB2Parser().parse(Data(fb2Sample.utf8))

        XCTAssertEqual(result.content.title, "Test Book")
        XCTAssertEqual(result.content.author, "Ivan Petrov")
        XCTAssertEqual(result.content.chapters.count, 2)

        let first = result.content.chapters[0]
        XCTAssertEqual(first.title, "Chapter One")
        XCTAssertEqual(first.blocks.first?.text, "First paragraph.")

        let second = result.content.chapters[1]
        XCTAssertEqual(second.title, "Nested")
        XCTAssertEqual(second.blocks.first?.text, "Nested text.")
    }

    func testFB2_inlineMarkup_flattenedIntoText() throws {
        let result = try FB2Parser().parse(Data(fb2Sample.utf8))
        XCTAssertTrue(result.content.chapters[0].blocks[1].text.contains("emphasis"))
        XCTAssertFalse(result.content.chapters[0].blocks[1].text.contains("<emphasis>"))
    }

    func testFB2_coverDecodedFromBinary() throws {
        let result = try FB2Parser().parse(Data(fb2Sample.utf8))
        XCTAssertEqual(result.coverData, Data(base64Encoded: "iVBORw0KGgo="))
    }

    func testFB2_malformed_throws() {
        XCTAssertThrowsError(try FB2Parser().parse(Data("<not-fb2/>".utf8)))
    }

    /// `src-title-info` holds the original-language title and author; the
    /// translation's own title wins.
    private let fb2WithSourceTitleInfo = """
    <?xml version="1.0" encoding="utf-8"?>
    <FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
      <description>
        <title-info>
          <book-title>Наодинці з собою</book-title>
          <author><first-name>Марк</first-name><last-name>Аврелій</last-name></author>
        </title-info>
        <src-title-info>
          <book-title>Εἰς ἑαυτόν</book-title>
          <author><first-name>Marcus</first-name><last-name>Aurelius</last-name></author>
        </src-title-info>
      </description>
      <body><section><p>Text.</p></section></body>
    </FictionBook>
    """

    func testFB2_prefersMainTitleAndAuthorOverSourceTitleInfo() throws {
        let result = try FB2Parser().parse(Data(fb2WithSourceTitleInfo.utf8))

        XCTAssertEqual(result.content.title, "Наодинці з собою")
        XCTAssertEqual(result.content.author, "Марк Аврелій")
    }

    // MARK: - TXT

    func testTXT_blankLineSeparatesParagraphs() {
        let text = "Para one line A\r\nPara one line B\r\n\r\nPara two"
        let content = TXTParser().parse(Data(text.utf8), title: nil)

        XCTAssertEqual(content.chapters.count, 1)
        XCTAssertEqual(content.chapters[0].blocks.count, 2)
        XCTAssertEqual(content.chapters[0].blocks[0].text, "Para one line A Para one line B")
        XCTAssertEqual(content.chapters[0].blocks[1].text, "Para two")
    }

    func testTXT_emptyData_singleEmptyParagraphFiltered() {
        let content = TXTParser().parse(Data("".utf8), title: "Empty")
        XCTAssertEqual(content.chapters.count, 1)
        XCTAssertEqual(content.chapters[0].blocks.count, 0)
        XCTAssertEqual(content.title, "Empty")
    }

    func testTXT_hugeSingleParagraph_keptAsOneBlock() {
        let text = String(repeating: "word ", count: 10_000)
        let content = TXTParser().parse(Data(text.utf8), title: nil)
        XCTAssertEqual(content.chapters[0].blocks.count, 1)
        XCTAssertTrue(content.chapters[0].blocks[0].text.hasSuffix("word"))
    }

    // MARK: - EPUB

    /// Minimal in-memory EPUB served by a dictionary file accessor.
    private func makeEPUBFiles() -> [String: Data] {
        let container = """
        <?xml version="1.0"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
        </container>
        """
        let opf = """
        <?xml version="1.0"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>EPUB Book</dc:title>
            <dc:creator>Jane Doe</dc:creator>
            <meta name="cover" content="cover-image"/>
          </metadata>
          <manifest>
            <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
            <item id="ch2" href="ch2.xhtml" media-type="application/xhtml+xml"/>
            <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="cover-image" href="cover.jpg" media-type="image/jpeg"/>
          </manifest>
          <spine>
            <itemref idref="ch1"/>
            <itemref idref="nav"/>
            <itemref idref="ch2"/>
          </spine>
        </package>
        """
        let ch1 = """
        <?xml version="1.0"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <head><title>ignored</title></head>
          <body><h1>Start</h1><p>Alpha &amp; beta.</p><p>Gamma.</p></body>
        </html>
        """
        let nav = "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body><p>just nav</p></body></html>"
        let ch2 = "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body><p>Final chapter.</p></body></html>"
        return [
            "META-INF/container.xml": Data(container.utf8),
            "OEBPS/content.opf": Data(opf.utf8),
            "OEBPS/ch1.xhtml": Data(ch1.utf8),
            "OEBPS/nav.xhtml": Data(nav.utf8),
            "OEBPS/ch2.xhtml": Data(ch2.utf8),
            "OEBPS/cover.jpg": Data([0xFF, 0xD8, 0xFF, 0xE0]),
        ]
    }

    func testEPUB_parsesSpineOrderSkipsNavReadsCover() throws {
        let files = makeEPUBFiles()
        let result = try EPUBParser().parse(fileAccessor: { files[$0] })

        XCTAssertEqual(result.content.title, "EPUB Book")
        XCTAssertEqual(result.content.author, "Jane Doe")

        let chapterTitles = result.content.chapters.compactMap(\.title)
        XCTAssertEqual(result.content.chapters.count, 2)

        let allBlocks = result.content.chapters.flatMap(\.blocks)
        XCTAssertEqual(allBlocks.first?.style, .heading)
        XCTAssertEqual(allBlocks.first?.text, "Start")
        XCTAssertTrue(allBlocks.contains { $0.text == "Alpha & beta." })
        XCTAssertTrue(allBlocks.contains { $0.text == "Final chapter." })
        XCTAssertFalse(allBlocks.contains { $0.text.contains("just nav") })
        XCTAssertEqual(chapterTitles.count, 0)
        XCTAssertEqual(result.coverData, Data([0xFF, 0xD8, 0xFF, 0xE0]))
    }

    func testEPUB_malformedXHTML_fallsBackToTagStripping() throws {
        var files = makeEPUBFiles()
        files["OEBPS/ch1.xhtml"] = Data("<html><body><p>Broken < entity &nbsp; here</p><p>Second</p></body></html>".utf8)
        // Not well-formed XML: unescaped raw ampersand forces fallback path.
        files["OEBPS/ch1.xhtml"] = Data("<html><body><p>Broken & raw</p><p>Second</p></body></html>".utf8)

        let frozen = files
        let result = try EPUBParser().parse(fileAccessor: { frozen[$0] })
        let texts = result.content.chapters.flatMap(\.blocks).map(\.text)
        XCTAssertTrue(texts.contains { $0.contains("Broken") })
        XCTAssertTrue(texts.contains { $0.contains("Second") })
    }

    func testEPUB_missingContainer_throws() {
        XCTAssertThrowsError(try EPUBParser().parse(fileAccessor: { _ in nil }))
    }
}
