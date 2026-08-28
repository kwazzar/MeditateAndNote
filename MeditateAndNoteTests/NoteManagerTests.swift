//
//  NoteManagerTests.swift
//  MeditateAndNoteTests
//
//  Covers the NoteBook aggregate and the application-service (NoteManager)
//  invariants: one entry per NoteID, last-write-wins by date.
//

import XCTest
@testable import MeditateAndNote

final class NoteManagerTests: XCTestCase {

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func makeSUT(seedLocal: [Note] = [], seedRemote: [Note] = [])
        -> (manager: NoteManager, capture: EventCapture, remote: InMemoryNoteDataSource) {
        let local = InMemoryNoteDataSource(seedNotes: seedLocal)
        let remote = InMemoryNoteDataSource(seedNotes: seedRemote)
        let sync = DefaultNoteSyncCoordinator(local: local, remote: remote)
        let bus = DomainEventBus()
        let capture = EventCapture(bus: bus)
        let manager = NoteManager(syncCoordinator: sync, eventBus: bus)
        return (manager, capture, remote)
    }

    // MARK: - NoteBook aggregate

    func testNoteBook_upsertKeepsNewestVersion() {
        let id = NoteID()
        let older = Note(id: id, title: "Old", content: "old", date: date(2026, 8, 1))
        let newer = Note(id: id, title: "New", content: "new", date: date(2026, 8, 2))

        var book = NoteBook(notes: [older])
        book.upsert(newer)

        XCTAssertEqual(book.notes.count, 1)
        XCTAssertEqual(book.notes.first, newer)
    }

    func testNoteBook_mergedReportsConflictsAndKeepsNewest() {
        let id = NoteID()
        let local = Note(id: id, title: "Local", content: "local", date: date(2026, 8, 1))
        let remote = Note(id: id, title: "Remote", content: "remote", date: date(2026, 8, 2))

        let outcome = NoteBook.merged(local: [local], remote: [remote])

        XCTAssertEqual(outcome.conflicts.count, 1)
        XCTAssertEqual(outcome.conflicts.first?.id, id)
        XCTAssertEqual(outcome.notes.count, 1)
        XCTAssertEqual(outcome.notes.first, remote)
    }

    // MARK: - NoteManager lifecycle

    func testAdd_exposesNoteAndPublishesEvent() async throws {
        let (manager, capture, _) = makeSUT()
        let note = Note(title: "Hello", content: "World")

        try await manager.add(note)

        let notes = await manager.currentNotes
        XCTAssertEqual(notes, [note])
        XCTAssertEqual(capture.createdCount, 1)
    }

    func testUpdate_replacesContentInPlace() async throws {
        let (manager, _, _) = makeSUT()
        let note = Note(title: "A", content: "1")
        try await manager.add(note)
        let updated = note.updating(content: NoteContent("2"))

        try await manager.update(updated)

        let notes = await manager.currentNotes
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first, updated)
    }

    func testDelete_removesNote() async throws {
        let (manager, _, _) = makeSUT()
        let note = Note(title: "x", content: "y")
        try await manager.add(note)

        try await manager.delete(with: note.id)

        let notes = await manager.currentNotes
        XCTAssertTrue(notes.isEmpty)
    }

    func testCollidingIDs_collapseToSingleEntry() async throws {
        let (manager, _, _) = makeSUT()
        let note = Note(title: "S", content: "1")

        try await manager.add(note)
        try await manager.add(note.updating(content: NoteContent("2")))

        let notes = await manager.currentNotes
        XCTAssertEqual(notes.count, 1, "Same NoteID must never produce duplicates")
        XCTAssertEqual(notes.first?.content, NoteContent("2"))
    }

    func testRefresh_resolvesNewestVersionAcrossSources() async throws {
        let id = NoteID()
        let (manager, _, _) = makeSUT(
            seedLocal: [Note(id: id, title: "Local", content: "local", date: date(2026, 8, 1))],
            seedRemote: [Note(id: id, title: "Remote", content: "remote", date: date(2026, 8, 2))]
        )

        await manager.refresh()

        let notes = await manager.currentNotes
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.content, NoteContent("remote"))
    }
}

private final class EventCapture {
    private(set) var events: [DomainEvent] = []

    init(bus: DomainEventBus) {
        _ = bus.subscribe { [weak self] event in
            self?.events.append(event)
        }
    }

    var createdCount: Int {
        events.filter {
            if case .noteCreated = $0 { return true }
            return false
        }.count
    }
}