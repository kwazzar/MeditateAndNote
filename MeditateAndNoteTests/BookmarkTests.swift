//
//  BookmarkTests.swift
//  MeditateAndNoteTests
//

import XCTest
import MeditateAndNoteCore
@testable import MeditateAndNote

final class BookmarkStoreTests: XCTestCase {

    private var manager: CoreDataManager!
    private var coreDataStore: CoreDataBookmarkStore!
    private var inMemoryStore: InMemoryBookmarkStore!

    override func setUp() {
        super.setUp()
        manager = CoreDataManager(inMemory: true)
        coreDataStore = CoreDataBookmarkStore(manager: manager)
        inMemoryStore = InMemoryBookmarkStore()
    }

    override func tearDown() {
        coreDataStore = nil
        inMemoryStore = nil
        manager = nil
        super.tearDown()
    }

    private func makeBook() -> BookID { BookID() }

    func testCoreData_saveFetchRoundTrip() async throws {
        let bookID = makeBook()
        let mark = Bookmark.highlight(bookID, at: ReadingPosition(chapterIndex: 2, blockIndex: 5, characterOffset: 11), text: "a passage")
        try await coreDataStore.save(mark)

        let fetched = try await coreDataStore.fetch(id: mark.id)
        XCTAssertEqual(fetched, mark)
        XCTAssertEqual(fetched?.text, "a passage")
        XCTAssertTrue(fetched?.isHighlight == true)
    }

    func testCoreData_fetchAll_filtersByBook() async throws {
        let bookA = makeBook()
        let bookB = makeBook()
        try await coreDataStore.save(.page(bookA, at: ReadingPosition()))
        try await coreDataStore.save(.page(bookB, at: ReadingPosition()))

        let forA = try await coreDataStore.fetchAll(bookID: bookA)
        XCTAssertEqual(forA.count, 1)
        XCTAssertEqual(forA.first?.bookID, bookA)
    }

    func testCoreData_deleteAndDeleteAll() async throws {
        let bookID = makeBook()
        let mark = Bookmark.page(bookID, at: ReadingPosition())
        try await coreDataStore.save(mark)

        try await coreDataStore.deleteAll(bookID: bookID)
        let remaining = try await coreDataStore.fetchAll(bookID: bookID)
        XCTAssertTrue(remaining.isEmpty)

        let other = Bookmark.page(bookID, at: ReadingPosition())
        try await coreDataStore.save(other)
        try await coreDataStore.delete(id: other.id)
        let deleted = try await coreDataStore.fetch(id: other.id)
        XCTAssertNil(deleted)
    }

    func testInMemory_roundTrip() async throws {
        let bookID = makeBook()
        let mark = Bookmark.highlight(bookID, at: ReadingPosition(), text: "text", noteID: NoteID())
        try await inMemoryStore.save(mark)

        let fetched = try await inMemoryStore.fetch(id: mark.id)
        XCTAssertEqual(fetched, mark)
        XCTAssertNotNil(fetched?.noteID)

        try await inMemoryStore.deleteAll(bookID: bookID)
        let left = try await inMemoryStore.fetchAll(bookID: bookID)
        XCTAssertTrue(left.isEmpty)
    }
}

final class BookmarkManagerTests: XCTestCase {

    private var store: InMemoryBookmarkStore!
    private var notes: InMemoryNoteDataSource!
    private var sut: BookmarkManager!

    override func setUp() {
        super.setUp()
        store = InMemoryBookmarkStore()
        notes = InMemoryNoteDataSource()
        sut = BookmarkManager(store: store, noteWriter: NoteManager(local: notes))
    }

    override func tearDown() {
        sut = nil
        notes = nil
        store = nil
        super.tearDown()
    }

    func testCreateHighlight_withoutNote_leavesNoteEmpty() async throws {
        let bookID = BookID()
        let mark = try await sut.createHighlight(
            bookID: bookID,
            position: ReadingPosition(),
            text: "a passage",
            bookTitle: "Book",
            location: "page 3",
            asNote: false
        )

        XCTAssertEqual(mark.text, "a passage")
        XCTAssertNil(mark.noteID)
        let stored = try await store.fetchAll(bookID: bookID)
        XCTAssertEqual(stored.count, 1)
        let written = try await notes.fetchAll()
        XCTAssertTrue(written.isEmpty)
    }

    func testCreateHighlight_asNote_writesNoteAndLinksIt() async throws {
        let bookID = BookID()
        let mark = try await sut.createHighlight(
            bookID: bookID,
            position: ReadingPosition(chapterIndex: 1, blockIndex: 2, characterOffset: 3),
            text: "a passage",
            bookTitle: "Book",
            location: "page 3",
            asNote: true
        )

        let noteID = try XCTUnwrap(mark.noteID)
        let all = try await notes.fetchAll()
        XCTAssertEqual(all.count, 1)
        let note = try XCTUnwrap(all.first { $0.id == noteID })
        XCTAssertTrue(note.content.rawValue.contains("a passage"))
        XCTAssertTrue(note.content.rawValue.contains("page 3"))
        XCTAssertEqual(note.title.rawValue, "Book")
    }

    func testAddAndDeleteMarks() async throws {
        let bookID = BookID()
        let mark = Bookmark.page(bookID, at: ReadingPosition())
        try await sut.add(mark)
        let stored = try await sut.bookmarks(for: bookID)
        XCTAssertEqual(stored.count, 1)

        try await sut.delete(id: mark.id)
        let left = try await sut.bookmarks(for: bookID)
        XCTAssertTrue(left.isEmpty)
    }
}
