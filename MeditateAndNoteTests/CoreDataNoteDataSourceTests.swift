//
//  CoreDataNoteDataSourceTests.swift
//  MeditateAndNoteTests
//

import XCTest
@testable import MeditateAndNote

final class CoreDataNoteDataSourceTests: XCTestCase {

    private var manager: CoreDataManager!
    private var sut: CoreDataNoteDataSource!

    override func setUp() {
        super.setUp()
        manager = CoreDataManager(inMemory: true)
        sut = CoreDataNoteDataSource(manager: manager)
    }

    override func tearDown() {
        sut = nil
        manager = nil
        super.tearDown()
    }

    // MARK: - Save / Fetch All

    func testSaveThenFetchAll_roundTripsNote() async throws {
        let note = Note(title: "Title", content: "Content", date: date(2026, 8, 20))

        try await sut.save(note)

        let fetched = try await sut.fetchAll()
        XCTAssertEqual(fetched, [note])
    }

    func testSaveMultipleNotes_fetchAllReturnsAll() async throws {
        let n1 = Note(title: "One", content: "1", date: date(2026, 8, 18))
        let n2 = Note(title: "Two", content: "2", date: date(2026, 8, 19))

        try await sut.save(n1)
        try await sut.save(n2)

        let fetched = try await sut.fetchAll()
        XCTAssertEqual(Set(fetched.map(\.id)), Set([n1, n2].map(\.id)))
    }

    // MARK: - Fetch by ID

    func testFetchByID_returnsNote() async throws {
        let note = Note(title: "Find me", content: "x", date: date(2026, 8, 20))
        try await sut.save(note)

        let fetched = try await sut.fetch(id: note.id)
        XCTAssertEqual(fetched, note)
    }

    func testFetchByID_missingNote_returnsNil() async throws {
        let fetched = try await sut.fetch(id: NoteID())
        XCTAssertNil(fetched)
    }

    // MARK: - Upsert

    func testSaveWithSameID_updatesExistingNote() async throws {
        let original = Note(title: "Original", content: "A", date: date(2026, 8, 20))
        try await sut.save(original)

        let updated = original.updating(content: NoteContent("B"))
        try await sut.save(updated)

        let fetched = try await sut.fetch(id: original.id)
        XCTAssertEqual(fetched, updated)

        let allAfterUpsert = try await sut.fetchAll()
        XCTAssertEqual(allAfterUpsert.count, 1, "Upsert must not duplicate rows")
    }

    // MARK: - Delete

    func testDelete_removesNote() async throws {
        let note = Note(title: "Delete me", content: "x", date: date(2026, 8, 20))
        try await sut.save(note)

        try await sut.delete(id: note.id)

        let afterDelete = try await sut.fetch(id: note.id)
        XCTAssertNil(afterDelete)

        let allAfterDelete = try await sut.fetchAll()
        XCTAssertTrue(allAfterDelete.isEmpty)
    }

    func testDelete_missingNote_isNoOp() async throws {
        try await sut.delete(id: NoteID())

        let all = try await sut.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - Delete All

    func testDeleteAll_clearsStore() async throws {
        let n1 = Note(title: "One", content: "1", date: date(2026, 8, 20))
        let n2 = Note(title: "Two", content: "2", date: date(2026, 8, 21))
        try await sut.save(n1)
        try await sut.save(n2)

        try await sut.deleteAll()

        let all = try await sut.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - Sorting

    func testFetchAll_sortedByDateDescending() async throws {
        let newer = Note(title: "Newer", content: "1", date: date(2026, 8, 25))
        let older = Note(title: "Older", content: "2", date: date(2026, 8, 20))
        let middle = Note(title: "Middle", content: "3", date: date(2026, 8, 22))
        try await sut.save(older)
        try await sut.save(middle)
        try await sut.save(newer)

        let fetched = try await sut.fetchAll()
        XCTAssertEqual(fetched.map(\.id), [newer, middle, older].map(\.id))
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return Calendar(identifier: .gregorian).date(from: comps)!
    }
}