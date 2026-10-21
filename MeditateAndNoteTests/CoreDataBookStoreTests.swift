//
//  CoreDataBookStoreTests.swift
//  MeditateAndNoteTests
//

import XCTest
import MeditateAndNoteCore
@testable import MeditateAndNote

final class BookStoreTests: XCTestCase {

    private var manager: CoreDataManager!
    private var coreDataStore: CoreDataBookStore!
    private var inMemoryStore: InMemoryBookStore!

    override func setUp() {
        super.setUp()
        manager = CoreDataManager(inMemory: true)
        coreDataStore = CoreDataBookStore(manager: manager)
        inMemoryStore = InMemoryBookStore()
    }

    override func tearDown() {
        coreDataStore = nil
        inMemoryStore = nil
        manager = nil
        super.tearDown()
    }

    private func makeBook(title: String = "Book") -> Book {
        Book(title: title, author: "Author", format: .fb2, fileName: "\(UUID().uuidString).fb2")
    }

    func testCoreData_saveFetchRoundTrip() async throws {
        let book = makeBook()
        try await coreDataStore.save(book)

        let fetched = try await coreDataStore.fetch(id: book.id)
        XCTAssertEqual(fetched, book)
    }

    func testCoreData_updateOverwrites() async throws {
        let book = makeBook()
        try await coreDataStore.save(book)

        var updated = book
        updated.title = "Renamed"
        updated.lastOpenedAt = Date()
        try await coreDataStore.save(updated)

        let fetched = try await coreDataStore.fetch(id: book.id)
        XCTAssertEqual(fetched?.title, "Renamed")
        XCTAssertNotNil(fetched?.lastOpenedAt)
    }

    func testCoreData_delete() async throws {
        let book = makeBook()
        try await coreDataStore.save(book)
        try await coreDataStore.delete(id: book.id)

        let fetched = try await coreDataStore.fetch(id: book.id)
        XCTAssertNil(fetched)
    }

    func testCoreData_readingPositionRoundTrip() async throws {
        let book = makeBook()
        try await coreDataStore.save(book)

        let position = ReadingPosition(chapterIndex: 3, blockIndex: 7, characterOffset: 42)
        try await coreDataStore.saveReadingPosition(position, for: book.id)

        let stored = try await coreDataStore.readingPosition(for: book.id)
        XCTAssertEqual(stored, position)
    }

    func testCoreData_coverRoundTrip() async throws {
        let book = makeBook()
        try await coreDataStore.save(book)

        let cover = Data([1, 2, 3])
        try await coreDataStore.saveCoverData(cover, for: book.id)
        let stored = try await coreDataStore.coverData(for: book.id)
        XCTAssertEqual(stored, cover)

        try await coreDataStore.saveCoverData(nil, for: book.id)
        let cleared = try await coreDataStore.coverData(for: book.id)
        XCTAssertNil(cleared)
    }

    func testInMemory_fullContract() async throws {
        let book = makeBook(title: "InMem")
        try await inMemoryStore.save(book)

        var fetched = try await inMemoryStore.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "InMem")

        let position = ReadingPosition(chapterIndex: 1, blockIndex: 2, characterOffset: 3)
        try await inMemoryStore.saveReadingPosition(position, for: book.id)
        let storedPosition = try await inMemoryStore.readingPosition(for: book.id)
        XCTAssertEqual(storedPosition, position)

        try await inMemoryStore.saveCoverData(Data([9]), for: book.id)
        let storedCover = try await inMemoryStore.coverData(for: book.id)
        XCTAssertEqual(storedCover, Data([9]))

        try await inMemoryStore.delete(id: book.id)
        fetched = try await inMemoryStore.fetchAll()
        XCTAssertTrue(fetched.isEmpty)
        let deletedPosition = try await inMemoryStore.readingPosition(for: book.id)
        XCTAssertNil(deletedPosition)
    }
}
