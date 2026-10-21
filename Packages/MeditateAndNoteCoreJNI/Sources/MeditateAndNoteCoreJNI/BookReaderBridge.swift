//
//  BookReaderBridge.swift
//  MeditateAndNoteCoreJNI
//
//  Read-path entry points for the Android book reader UI.
//
//  Same wire-format rule as `NoteMenuSource_read`: Swift returns flat JSON of
//  display records; Kotlin parses that wire format (defined here, not by the
//  Core schema) and never sees Core-owned documents.
//
//  Pagination runs in Swift (the engine is in the shared Core package) and the
//  laid-out book is cached process-wide, so page turns never re-parse or
//  re-wrap; a font-size change re-paginates and returns the page the reader
//  should land on.
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

// MARK: - JSON wire helpers

private func jwire(
    _ object: [String: Any],
    in environment: UnsafeMutablePointer<JNIEnv?>!
) -> jstring? {
    guard let payload = try? JSONSerialization.data(withJSONObject: object),
          let json = String(data: payload, encoding: .utf8) else {
        return nil
    }
    return json.getJNILocalRefValue(in: environment)
}

// MARK: - Content parsing (shared by reader + import)

enum BookContentParsing {
    /// Parses a stored book file by format.
    static func parse(_ book: Book) throws -> (content: BookContent, coverData: Data?) {
        switch book.format {
        case .fb2:
            let data = try loadData(for: book)
            let result = try FB2Parser().parse(data)
            return (result.content, result.coverData)
        case .epub:
            let loader = try MiniZipReader(url: URL(fileURLWithPath: book.fileName))
            let result = try EPUBParser().parse(fileAccessor: { path in
                loader.entry(named: path).flatMap(loader.read)
            })
            return (result.content, result.coverData)
        case .txt:
            let data = try loadData(for: book)
            let content = TXTParser().parse(data, title: book.title)
            return (content, nil)
        }
    }

    private static func loadData(for book: Book) throws -> Data {
        guard let data = BookFileBridge.loadData(path: book.fileName) else {
            throw BookParseError.invalidFormat("book file missing at \(book.fileName)")
        }
        return data
    }
}

// MARK: - Library list

/// Returns the library as a wire JSON array of display records:
/// `[{"id","title","author","format","progress"}]` (progress = per-mille).
///
/// `ponytail:` progress parses every book's content on each library load —
/// O(books × book size); cache per-book progress in the store row if a large
/// library ever measurably slows the tab down.
@_cdecl("Java_com_mn_android_data_BookSource_read")
public func Java_com_mn_android_data_BookSource_read(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass
) -> jstring? {
    let store = KotlinBookStore()
    do {
        let books = try store.librarySync()
        var records: [[String: Any]] = []
        for book in books {
            var progress = 0.0
            if let position = try? store.positionSync(for: book.id),
               let parsed = try? BookContentParsing.parse(book) {
                progress = parsed.content.progress(of: position)
            }
            var record: [String: Any] = [
                "id": book.id.rawValue.uuidString,
                "title": book.title,
                "format": book.format.rawValue,
                "progress": Int(progress * 1000),
            ]
            record["author"] = book.author ?? ""
            records.append(record)
        }
        return jwire(["books": records], in: environment)
    } catch {
        KotlinBookStore.logProbeFailure(error)
        return nil
    }
}

// MARK: - Import

/// Full import flow: copy the picked file into storage, parse metadata + cover,
/// persist. Returns `{"id"}`, or `{"error"}` on failure.
@_cdecl("Java_com_mn_android_data_BookSource_importNative")
public func Java_com_mn_android_data_BookSource_importNative(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jSrcPath: jstring?,
    jFormat: jstring?
) -> jstring? {
    let src = String(fromJNI: jSrcPath, in: environment)
    let formatRaw = String(fromJNI: jFormat, in: environment)
    guard let format = BookFormat(rawValue: formatRaw) else {
        return jwire(["error": "unsupported format"], in: environment)
    }
    do {
        let store = KotlinBookStore()
        let bookID = BookID()
        let storedPath = BookFileBridge.importFile(
            srcPath: src,
            fileName: "\(bookID.rawValue.uuidString).\(format.rawValue)"
        )
        guard !storedPath.isEmpty else {
            return jwire(["error": "copy failed"], in: environment)
        }

        var book = Book(
            id: bookID,
            title: URL(fileURLWithPath: src).deletingPathExtension().lastPathComponent,
            format: format,
            fileName: storedPath
        )
        if let parsed = try? BookContentParsing.parse(book) {
            if let title = parsed.content.title, !title.isEmpty { book.title = title }
            book.author = parsed.content.author
            if let cover = parsed.coverData {
                try? store.saveCoverSync(cover, for: bookID)
            }
        }
        try store.saveSync(book)
        return jwire(["id": bookID.rawValue.uuidString], in: environment)
    } catch {
        KotlinBookStore.logProbeFailure(error)
        return jwire(["error": "import failed"], in: environment)
    }
}

/// Cover image for one book, base64-encoded, or "" when absent.
@_cdecl("Java_com_mn_android_data_BookSource_coverNative")
public func Java_com_mn_android_data_BookSource_coverNative(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jId: jstring?
) -> jstring? {
    let id = String(fromJNI: jId, in: environment)
    guard let uuid = UUID(uuidString: id) else {
        return "".getJNILocalRefValue(in: environment)
    }
    do {
        let cover = try KotlinBookStore().coverSync(for: BookID(rawValue: uuid))
        return (cover?.base64EncodedString() ?? "").getJNILocalRefValue(in: environment)
    } catch {
        KotlinBookStore.logProbeFailure(error)
        return "".getJNILocalRefValue(in: environment)
    }
}

// MARK: - Delete

@_cdecl("Java_com_mn_android_data_BookSource_deleteNative")
public func Java_com_mn_android_data_BookSource_deleteNative(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jId: jstring?
) {
    let id = String(fromJNI: jId, in: environment)
    guard let uuid = UUID(uuidString: id) else { return }
    do {
        try KotlinBookStore().deleteSync(BookID(rawValue: uuid))
    } catch {
        KotlinBookStore.logProbeFailure(error)
    }
}

// MARK: - Reader cache

/// One open book at a time on Android; keyed by book id + layout so a stale
/// page request can never render from the wrong layout.
private struct ReaderCacheKey: Hashable {
    let bookID: String
    let fontSize: Double
    let width: Double
    let height: Double
    let widthScale: Double
}

private final class ReaderCache: @unchecked Sendable {
    static let shared = ReaderCache()
    private var entry: (key: ReaderCacheKey, paginated: PaginatedBook)?
    private let lock = NSLock()

    func paginate(
        book: Book,
        content: BookContent,
        fontSize: Double,
        width: Double,
        height: Double,
        widthScale: Double,
        restoring position: ReadingPosition?
    ) -> (PaginatedBook, Int) {
        let key = ReaderCacheKey(
            bookID: book.id.rawValue.uuidString,
            fontSize: fontSize,
            width: width,
            height: height,
            widthScale: widthScale
        )
        lock.lock()
        defer { lock.unlock() }
        let engine = PaginationEngine(measurer: KotlinTextMeasurer(fontSize: fontSize, widthScale: widthScale))
        if let entry, entry.key == key {
            let page = position.flatMap { engine.page(of: $0, in: entry.paginated) } ?? 0
            return (entry.paginated, page)
        }
        let paginated = engine.paginate(content, pageSize: PageSize(width: width, height: height))
        let page = position.flatMap { engine.page(of: $0, in: paginated) } ?? 0
        entry = (key, paginated)
        return (paginated, page)
    }

    func current() -> (key: ReaderCacheKey, paginated: PaginatedBook)? {
        lock.lock()
        defer { lock.unlock() }
        return entry
    }
}

// MARK: - Reader

/// Opens a book for reading: parses, paginates with the Kotlin Paint measurer,
/// restores the saved position, caches the layout. Wire JSON:
/// `{"title","pageCount","page"}`.
@_cdecl("Java_com_mn_android_data_ReaderSource_openNative")
public func Java_com_mn_android_data_ReaderSource_openNative(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jId: jstring?,
    fontSize: jdouble,
    width: jdouble,
    height: jdouble,
    widthScale: jdouble
) -> jstring? {
    return withReaderContext(jId, in: environment) { book, content, position in
        let (paginated, page) = ReaderCache.shared.paginate(
            book: book,
            content: content,
            fontSize: fontSize,
            width: width,
            height: height,
            widthScale: widthScale,
            restoring: position
        )
        return ["title": book.title, "pageCount": paginated.pages.count, "page": page]
    }
}

/// One cached page. Wire JSON: `{"lines":[...],"progress"}` (progress 0–1).
@_cdecl("Java_com_mn_android_data_ReaderSource_pageNative")
public func Java_com_mn_android_data_ReaderSource_pageNative(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    index: jint
) -> jstring? {
    guard let entry = ReaderCache.shared.current() else { return nil }
    let paginated = entry.paginated
    let clamped = min(max(Int(index), 0), paginated.pages.count - 1)
    let page = paginated.pages[clamped]
    let positions: [[String: Any]] = page.linePositions.map { position in
        [
            "chapter": position.chapterIndex,
            "block": position.blockIndex,
            "offset": position.characterOffset,
        ]
    }
    return jwire([
        "lines": page.lines,
        "positions": positions,
        "progress": paginated.progress(ofPageAt: clamped),
    ], in: environment)
}

/// Re-paginates (font size change) and returns the page the reader should land
/// on: `{"pageCount","page"}`.
@_cdecl("Java_com_mn_android_data_ReaderSource_repaginateNative")
public func Java_com_mn_android_data_ReaderSource_repaginateNative(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jId: jstring?,
    fontSize: jdouble,
    width: jdouble,
    height: jdouble,
    widthScale: jdouble
) -> jstring? {
    return withReaderContext(jId, in: environment) { book, content, position in
        let (paginated, page) = ReaderCache.shared.paginate(
            book: book,
            content: content,
            fontSize: fontSize,
            width: width,
            height: height,
            widthScale: widthScale,
            restoring: position
        )
        return ["pageCount": paginated.pages.count, "page": page]
    }
}

/// Persists the logical position of a page (by index into the cached layout).
@_cdecl("Java_com_mn_android_data_ReaderSource_savePositionNative")
public func Java_com_mn_android_data_ReaderSource_savePositionNative(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jId: jstring?,
    index: jint
) {
    let id = String(fromJNI: jId, in: environment)
    guard let uuid = UUID(uuidString: id),
          let entry = ReaderCache.shared.current() else { return }
    let engine = PaginationEngine(
        measurer: KotlinTextMeasurer(fontSize: entry.key.fontSize, widthScale: entry.key.widthScale)
    )
    let position = engine.position(atPage: Int(index), in: entry.paginated)
    try? KotlinBookStore().saveReadingPositionSync(position, for: BookID(rawValue: uuid))
}

// MARK: - Shared plumbing

/// Reads the book + content + saved position once for the open/repaginate calls.
private func withReaderContext(
    _ jId: jstring?,
    in environment: UnsafeMutablePointer<JNIEnv?>!,
    _ body: (Book, BookContent, ReadingPosition?) -> [String: Any]
) -> jstring? {
    let id = String(fromJNI: jId, in: environment)
    guard let uuid = UUID(uuidString: id) else { return nil }
    do {
        let store = KotlinBookStore()
        guard let book = try store.librarySync().first(where: { $0.id.rawValue == uuid }) else {
            return nil
        }
        let parsed = try BookContentParsing.parse(book)
        let position = try? store.positionSync(for: book.id)
        return jwire(body(book, parsed.content, position), in: environment)
    } catch {
        KotlinBookStore.logProbeFailure(error)
        return nil
    }
}

// MARK: - Table of contents

/// Chapters of the open book with the page each one starts on.
/// Wire JSON: `[{"chapter","title","page"}]`.
@_cdecl("Java_com_mn_android_data_BookmarksSource_tocNative")
public func Java_com_mn_android_data_BookmarksSource_tocNative(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jId: jstring?
) -> jstring? {
    let id = String(fromJNI: jId, in: environment)
    guard let uuid = UUID(uuidString: id) else { return nil }
    do {
        let store = KotlinBookStore()
        guard let book = try store.librarySync().first(where: { $0.id.rawValue == uuid }) else {
            return nil
        }
        let parsed = try BookContentParsing.parse(book)
        let entry = ReaderCache.shared.current()
        var records: [[String: Any]] = []
        for (index, chapter) in parsed.content.chapters.enumerated() {
            var page = 0
            if let entry {
                if let first = entry.paginated.pages.firstIndex(where: { $0.origin.chapterIndex == index }) {
                    page = first
                }
            }
            records.append([
                "chapter": index,
                "title": chapter.title?.isEmpty == false ? chapter.title! : "Chapter \(index + 1)",
                "page": page,
            ])
        }
        return jwire(["chapters": records], in: environment)
    } catch {
        KotlinBookStore.logProbeFailure(error)
        return nil
    }
}

/// The page a logical position resolves to in the current layout.
@_cdecl("Java_com_mn_android_data_BookmarksSource_pageForPositionNative")
public func Java_com_mn_android_data_BookmarksSource_pageForPositionNative(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    chapter: jint,
    block: jint,
    offset: jint
) -> jint {
    guard let entry = ReaderCache.shared.current() else { return 0 }
    let position = ReadingPosition(
        chapterIndex: Int(chapter),
        blockIndex: Int(block),
        characterOffset: Int(offset)
    )
    let engine = PaginationEngine(
        measurer: KotlinTextMeasurer(fontSize: entry.key.fontSize, widthScale: entry.key.widthScale)
    )
    return jint(engine.page(of: position, in: entry.paginated) ?? 0)
}

// MARK: - Marks (bookmarks + highlights)

/// The reader's marks in one book. Wire JSON:
/// `[{"id","chapter","block","offset","text","noteId","createdAt"}]`.
@_cdecl("Java_com_mn_android_data_BookmarksSource_readNative")
public func Java_com_mn_android_data_BookmarksSource_readNative(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jId: jstring?
) -> jstring? {
    let id = String(fromJNI: jId, in: environment)
    guard let uuid = UUID(uuidString: id) else { return nil }
    do {
        let marks = try KotlinBookmarkStore().allSync().filter { $0.bookID.rawValue == uuid }
        let records: [[String: Any]] = marks.map { mark in
            [
                "id": mark.id.rawValue.uuidString,
                "chapter": mark.position.chapterIndex,
                "block": mark.position.blockIndex,
                "offset": mark.position.characterOffset,
                "text": mark.text ?? "",
                "noteId": mark.noteID?.rawValue.uuidString ?? "",
                "createdAt": mark.createdAt.timeIntervalSince1970 * 1000.0,
            ]
        }
        return jwire(["marks": records], in: environment)
    } catch {
        KotlinBookStore.logProbeFailure(error)
        return nil
    }
}

/// Adds a page bookmark. Returns the mark id.
@_cdecl("Java_com_mn_android_data_BookmarksSource_addPageNative")
public func Java_com_mn_android_data_BookmarksSource_addPageNative(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jId: jstring?,
    chapter: jint,
    block: jint,
    offset: jint
) -> jstring? {
    let id = String(fromJNI: jId, in: environment)
    guard let uuid = UUID(uuidString: id) else { return nil }
    do {
        let mark = Bookmark.page(
            BookID(rawValue: uuid),
            at: ReadingPosition(chapterIndex: Int(chapter), blockIndex: Int(block), characterOffset: Int(offset))
        )
        try KotlinBookmarkStore().saveSync(mark)
        return jstringFor(mark.id.rawValue.uuidString, in: environment)
    } catch {
        KotlinBookStore.logProbeFailure(error)
        return nil
    }
}

/// Adds a highlight; with `asNote` it also writes a note with the passage.
/// Returns the mark id.
@_cdecl("Java_com_mn_android_data_BookmarksSource_addHighlightNative")
public func Java_com_mn_android_data_BookmarksSource_addHighlightNative(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jId: jstring?,
    chapter: jint,
    block: jint,
    offset: jint,
    jText: jstring?,
    jBookTitle: jstring?,
    jLocation: jstring?,
    asNote: jboolean
) -> jstring? {
    let id = String(fromJNI: jId, in: environment)
    let text = String(fromJNI: jText, in: environment)
    let bookTitle = String(fromJNI: jBookTitle, in: environment)
    let location = String(fromJNI: jLocation, in: environment)
    guard let uuid = UUID(uuidString: id) else { return nil }
    do {
        var mark = Bookmark.highlight(
            BookID(rawValue: uuid),
            at: ReadingPosition(chapterIndex: Int(chapter), blockIndex: Int(block), characterOffset: Int(offset)),
            text: text
        )
        if asNote != 0 {
            let note = Note(
                title: NoteTitle(bookTitle),
                content: NoteContent("\"\(text)\"\n\n— \(bookTitle), \(location)")
            )
            try KotlinNoteDataSource().saveSync(note)
            mark.noteID = note.id
        }
        try KotlinBookmarkStore().saveSync(mark)
        return jstringFor(mark.id.rawValue.uuidString, in: environment)
    } catch {
        KotlinBookStore.logProbeFailure(error)
        return nil
    }
}

/// Removes a mark by id.
@_cdecl("Java_com_mn_android_data_BookmarksSource_deleteNative")
public func Java_com_mn_android_data_BookmarksSource_deleteNative(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jId: jstring?
) {
    let id = String(fromJNI: jId, in: environment)
    guard let uuid = UUID(uuidString: id) else { return }
    do {
        try KotlinBookmarkStore().deleteSync(BookmarkID(rawValue: uuid))
    } catch {
        KotlinBookStore.logProbeFailure(error)
    }
}

private func jstringFor(_ value: String, in environment: UnsafeMutablePointer<JNIEnv?>!) -> jstring? {
    value.getJNILocalRefValue(in: environment)
}
