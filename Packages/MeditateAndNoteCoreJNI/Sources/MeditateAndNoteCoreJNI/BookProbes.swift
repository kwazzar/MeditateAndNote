//
//  BookProbes.swift
//  MeditateAndNoteCoreJNI
//
//  Device probes for the book domain on Android: the `KotlinBookStore` round
//  trip through SharedPreferences, the parsers, and the pagination engine.
//
//  Results are flags written into a LongArray Kotlin allocated — same rule as
//  every other probe: Kotlin cannot observe Swift replacing an out-param.
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

// MARK: - Book store probe

/// Kotlin side: `BookStoreProbe.kt`. Slots (9):
/// 0 saved, 1 fetched count, 2 title survived, 3 position round trip,
/// 4 cover round trip, 5 update replaced, 6 delete cleared, 7 imported file
/// readable, 8 threw.
@_cdecl("Java_com_mn_android_debug_NativeProbe_bookStoreProbe")
public func Java_com_mn_android_debug_NativeProbe_bookStoreProbe(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    out: jlongArray
) {
    let store = KotlinBookStore()
    var results = [Int64](repeating: 0, count: 9)

    do {
        let book = Book(
            id: BookID(),
            title: "Probe Book",
            author: "Probe Author",
            format: .fb2,
            fileName: "probe.fb2"
        )
        try store.saveSync(book)
        results[0] = 1

        // Scoped to the probe's own book: the store may hold the user's
        // imported books, and a count check would fail on their data.
        let mine = try store.librarySync().first { $0.id == book.id }
        results[1] = mine == nil ? 0 : 1
        results[2] = mine?.title == "Probe Book" ? 1 : 0

        let position = ReadingPosition(chapterIndex: 2, blockIndex: 3, characterOffset: 40)
        try store.saveReadingPositionSync(position, for: book.id)
        let loaded = try store.positionSync(for: book.id)
        results[3] = loaded == position ? 1 : 0

        try store.saveCoverSync(Data([1, 2, 3]), for: book.id)
        let cover = try store.coverSync(for: book.id)
        results[4] = cover == Data([1, 2, 3]) ? 1 : 0

        var updated = book
        updated.title = "Renamed"
        try store.saveSync(updated)
        results[5] = try store.librarySync().first { $0.id == book.id }?.title == "Renamed" ? 1 : 0

        try store.deleteSync(book.id)
        results[6] = try store.librarySync().first { $0.id == book.id } == nil ? 1 : 0

        // File import: write a source file, copy it through Kotlin, read back.
        let src = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("probe-src-\(UUID().uuidString).txt")
        try Data("hello book".utf8).write(to: src)
        defer { try? FileManager.default.removeItem(at: src) }
        let stored = BookFileBridge.importFile(srcPath: src.path, fileName: "probe-import.txt")
        results[7] = (BookFileBridge.loadData(path: stored) == Data("hello book".utf8)) ? 1 : 0
        if !stored.isEmpty {
            BookFileBridge.deleteFile(path: stored)
        }
    } catch {
        KotlinBookStore.logProbeFailure(error)
        results[8] = 1
    }

    writeValues(results, to: out, in: environment)
}

// MARK: - Parser + pagination probe

/// Kotlin side: `PaginationProbe.kt`. Slots (9):
/// 0 FB2 chapters, 1 FB2 title, 2 FB2 paragraphs, 3 TXT paragraphs,
/// 4 pages laid out, 5 position round trip, 6 progress bounds,
/// 7 heading starts page, 8 threw.
@_cdecl("Java_com_mn_android_debug_NativeProbe_bookPaginationProbe")
public func Java_com_mn_android_debug_NativeProbe_bookPaginationProbe(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    out: jlongArray
) {
    var results = [Int64](repeating: 0, count: 9)

    do {
        let longText = String(repeating: "word ", count: 400)
        let fb2 = """
        <?xml version="1.0" encoding="utf-8"?>
        <FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
          <description><title-info><book-title>Probe</book-title></title-info></description>
          <body><section><title><p>One</p></title><p>\(longText)</p></section></body>
        </FictionBook>
        """
        let parsed = try FB2Parser().parse(Data(fb2.utf8))
        results[0] = Int64(parsed.content.chapters.count)
        results[1] = parsed.content.title == "Probe" ? 1 : 0
        results[2] = Int64(parsed.content.chapters.first?.blocks.count ?? 0)

        let txt = TXTParser().parse(Data("One.\n\nTwo.".utf8), title: "T")
        results[3] = Int64(txt.chapters.first?.blocks.count ?? 0)

        // Pagination with a deterministic measurer: 10 units per character,
        // line height 10. Width 100 → 10 chars/line; height 30 → 3 lines/page.
        struct FixedMeasurer: TextMeasurer {
            func width(of text: String) -> Double { Double(text.count) * 10 }
            func lineHeight() -> Double { 10 }
        }
        let engine = PaginationEngine(measurer: FixedMeasurer())
        let paginated = engine.paginate(parsed.content, pageSize: PageSize(width: 100, height: 30))
        results[4] = Int64(paginated.pages.count)

        let midPage = paginated.pages.count / 2
        let position = engine.position(atPage: midPage, in: paginated)
        results[5] = engine.page(of: position, in: paginated) == midPage ? 1 : 0

        let progress = paginated.progress(ofPageAt: 0)
        results[6] = (progress >= 0 && progress < 1) ? 1 : 0

        let heading = BookContent(chapters: [BookChapter(blocks: [
            BookBlock(.paragraph, "first"),
            BookBlock(.heading, "Head"),
            BookBlock(.paragraph, "second"),
        ])])
        let headingPages = engine.paginate(heading, pageSize: PageSize(width: 100, height: 20))
        results[7] = headingPages.pages[0].lines.contains("Head") == false &&
            headingPages.pages.contains { $0.lines.first == "Head" } ? 1 : 0
    } catch {
        KotlinBookStore.logProbeFailure(error)
        results[8] = 1
    }

    writeValues(results, to: out, in: environment)
}

extension KotlinBookStore {
    // Probe-visible sync forms.
    func saveReadingPositionSync(_ position: ReadingPosition, for bookID: BookID) throws {
        let json = String(decoding: try JSONEncoder().encode(position), as: UTF8.self)
        try callSavePosition(id: bookID.rawValue.uuidString, json: json)
    }

    func saveCoverSync(_ data: Data, for bookID: BookID) throws {
        try callSaveCover(id: bookID.rawValue.uuidString, base64: data.base64EncodedString())
    }

    func coverSync(for bookID: BookID) throws -> Data? {
        let base64 = try callLoadCover(id: bookID.rawValue.uuidString)
        guard !base64.isEmpty else { return nil }
        return Data(base64Encoded: base64)
    }

    static func logProbeFailure(_ error: Error) {
        Self.logger.warning("book probe failed: \(error)")
    }
}
