//
//  BookManagerIntegrationTests.swift
//  MeditateAndNoteTests
//
//  End-to-end: import file → store → parse → paginate, real file storage.
//

import XCTest
import ZIPFoundation
import MeditateAndNoteCore
@testable import MeditateAndNote

final class BookManagerIntegrationTests: XCTestCase {

    private var storageDir: URL!
    private var manager: BookManager!

    override func setUp() {
        super.setUp()
        storageDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("book-tests-\(UUID().uuidString)", isDirectory: true)
        manager = BookManager(
            store: InMemoryBookStore(),
            fileStorage: BookFileStorage(directory: storageDir)
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: storageDir)
        manager = nil
        storageDir = nil
        super.tearDown()
    }

    private func writeSample(_ name: String, _ content: Data) throws -> URL {
        let url = storageDir.appendingPathComponent(name)
        try content.write(to: url)
        return url
    }

    private var fb2Sample: Data {
        Data("""
        <?xml version="1.0" encoding="utf-8"?>
        <FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
          <description><title-info><book-title>Integration FB2</book-title>
          <author><first-name>A</first-name><last-name>B</last-name></author></title-info></description>
          <body><section><title><p>One</p></title>
          <p>\(String(repeating: "text ", count: 400))</p></section></body>
        </FictionBook>
        """.utf8)
    }

    func testImportAndLoad_fb2() async throws {
        let source = try writeSample("sample.fb2", fb2Sample)

        let book = try await manager.importBook(from: source)
        XCTAssertEqual(book.title, "Integration FB2")
        XCTAssertEqual(book.author, "A B")
        XCTAssertEqual(book.format, .fb2)

        let (loaded, content, position) = try await manager.loadContent(for: book.id)
        XCTAssertEqual(loaded.id, book.id)
        XCTAssertEqual(content.title, "Integration FB2")
        XCTAssertFalse(content.chapters.isEmpty)
        XCTAssertEqual(position, ReadingPosition())

        let paginated = PaginationEngine(measurer: UITextMeasurer(fontSize: 18))
            .paginate(content, pageSize: PageSize(width: 340, height: 700))
        XCTAssertGreaterThan(paginated.pages.count, 1)
    }

    func testImportAndLoad_txt() async throws {
        let source = try writeSample("book.txt", Data("Para one.\n\nPara two.".utf8))
        let book = try await manager.importBook(from: source)
        XCTAssertEqual(book.title, "book")

        let (_, content, _) = try await manager.loadContent(for: book.id)
        XCTAssertEqual(content.chapters[0].blocks.count, 2)
    }

    func testImport_unsupportedExtension_throws() async throws {
        let source = try writeSample("doc.pdf", Data("%PDF".utf8))
        do {
            _ = try await manager.importBook(from: source)
            XCTFail("expected unsupportedFile")
        } catch BookImportError.unsupportedFile {
            // expected
        }
    }

    func testImportAndLoad_epub() async throws {
        // Assemble a real zip in memory via the same APIs the app target has.
        let container = """
        <?xml version="1.0"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
        </container>
        """
        let opf = """
        <?xml version="1.0"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Zip EPUB</dc:title></metadata>
          <manifest><item id="c" href="c.xhtml" media-type="application/xhtml+xml"/></manifest>
          <spine><itemref idref="c"/></spine>
        </package>
        """
        let chapter = "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body><p>Hello zip.</p></body></html>"

        let zipURL = storageDir.appendingPathComponent("sample.epub")
        let archive = try Archive(url: zipURL, accessMode: .create)
        for (path, text) in [("META-INF/container.xml", container), ("OEBPS/content.opf", opf), ("OEBPS/c.xhtml", chapter)] {
            let data = Data(text.utf8)
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate) { position, chunkSize in
                let start = Int(position)
                let end = min(start + chunkSize, data.count)
                return data[start..<end]
            }
        }

        let book = try await manager.importBook(from: zipURL)
        XCTAssertEqual(book.format, .epub)

        let (_, content, _) = try await manager.loadContent(for: book.id)
        XCTAssertEqual(content.title, "Zip EPUB")
        XCTAssertEqual(content.chapters[0].blocks.first?.text, "Hello zip.")
    }

    func testSavePositionAndProgress() async throws {
        let source = try writeSample("s.txt", Data(String(repeating: "word ", count: 100).utf8))
        let book = try await manager.importBook(from: source)

        var position = ReadingPosition(chapterIndex: 0, blockIndex: 0, characterOffset: 50)
        try await manager.saveReadingPosition(position, for: book.id)

        let progress = await manager.progress(for: book.id)
        XCTAssertGreaterThan(progress, 0)
        XCTAssertLessThan(progress, 1)
        _ = position
    }
}
