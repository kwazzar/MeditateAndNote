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

// MARK: - NoteEditorViewModel

/// Application-service spy behind the `NoteProvidable & NoteManageable`
/// contracts, with call recording and injectable failures.
actor NoteServiceSpy: NoteProvidable, NoteManageable {
    var notes: [Note] = []
    private(set) var added: [Note] = []
    private(set) var updated: [Note] = []
    private(set) var deletedIDs: [NoteID] = []
    private(set) var fetchCount = 0
    private(set) var refreshCount = 0
    private var failsLoad = false
    private var failsAdd = false
    private var failsDelete = false

    func setFailsLoadForTest(_ value: Bool) { failsLoad = value }
    func setFailsAddForTest(_ value: Bool) { failsAdd = value }
    func setFailsDeleteForTest(_ value: Bool) { failsDelete = value }


    var currentNotes: [Note] { notes }

    func note(with id: NoteID) async throws -> Note? {
        fetchCount += 1
        if failsLoad { throw NoteOperationError.loadFailed(id) }
        return notes.first { $0.id == id }
    }

    func notes(matching query: SearchQuery) async -> [Note] { notes }

    func refresh() async { refreshCount += 1 }

    func add(_ note: Note) async throws {
        if failsAdd { throw NoteOperationError.saveFailed }
        added.append(note)
        notes.append(note)
    }

    func update(_ note: Note) async throws {
        updated.append(note)
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
        }
    }

    func delete(with id: NoteID) async throws {
        if failsDelete { throw NoteOperationError.deleteFailed(id) }
        deletedIDs.append(id)
        notes.removeAll { $0.id == id }
    }
}

@MainActor
final class NoteEditorViewModelTests: XCTestCase {

    private func waitLoaded(_ spy: NoteServiceSpy, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<200 where await spy.fetchCount == 0 {
            try? await Task.sleep(for: .milliseconds(10))
        }
        try await Task.sleep(for: .milliseconds(20))
        let count = await spy.fetchCount
        XCTAssertGreaterThan(count, 0, "note(with:) was never called", file: file, line: line)
    }

    // MARK: - Init / load

    func testInit_newNote_startsEmpty() {
        let sut = NoteEditorViewModel(notes: NoteServiceSpy())
        XCTAssertEqual(sut.title, "")
        XCTAssertEqual(sut.body, "")
        XCTAssertTrue(sut.isNewNote)
        XCTAssertFalse(sut.isDirty)
    }

    func testInit_existingNote_loadsContent() async throws {
        let spy = NoteServiceSpy()
        let note = Note(title: "Persistent", content: "Stored")
        try await spy.update(note)

        let sut = NoteEditorViewModel(noteId: note.id, notes: spy)
        try await waitLoaded(spy)

        XCTAssertEqual(sut.title, "Persistent")
        XCTAssertEqual(sut.body, "Stored")
        XCTAssertFalse(sut.isNewNote)
        XCTAssertFalse(sut.isDirty)
    }

    func testInit_missingNote_entersNotFound_andSaveUpdatesWithSameID() async throws {
        let spy = NoteServiceSpy()
        let missingID = NoteID()

        let sut = NoteEditorViewModel(noteId: missingID, notes: spy)
        try await waitLoaded(spy)

        XCTAssertFalse(sut.isNewNote)
        XCTAssertFalse(sut.isDirty)

        sut.title = "Recreated"
        await sut.save()

        let updated = await spy.updated
        XCTAssertEqual(updated.count, 1, "notFound save must recreate via update, not add")
        XCTAssertEqual(updated.first?.id, missingID, "recreated note must keep the original id")
    }

    func testInit_loadFailure_entersNotFound() async throws {
        let spy = NoteServiceSpy()
        await spy.setFailsLoadForTest(true)
        let note = Note(title: "Gone", content: "")

        let sut = NoteEditorViewModel(noteId: note.id, notes: spy)
        try await waitLoaded(spy)

        XCTAssertFalse(sut.isNewNote)
        sut.title = "Recovered"
        XCTAssertTrue(sut.isDirty)
    }

    // MARK: - Dirty state

    func testIsDirty_newNote_tracksAnyContent() {
        let sut = NoteEditorViewModel(notes: NoteServiceSpy())
        XCTAssertFalse(sut.isDirty)

        sut.title = "Draft"
        XCTAssertTrue(sut.isDirty)

        sut.title = ""
        XCTAssertFalse(sut.isDirty)

        sut.body = "Something"
        XCTAssertTrue(sut.isDirty)
    }

    func testIsDirty_existingNote_comparesAgainstPersisted() async throws {
        let spy = NoteServiceSpy()
        let note = Note(title: "Original", content: "Content")
        try await spy.update(note)

        let sut = NoteEditorViewModel(noteId: note.id, notes: spy)
        try await waitLoaded(spy)

        sut.title = "Changed"
        XCTAssertTrue(sut.isDirty)

        sut.title = "Original"
        XCTAssertFalse(sut.isDirty, "reverting to persisted value must clear dirty state")
    }

    // MARK: - Save

    func testSave_newNote_addsNormalizesTitleAndTransitionsToLoaded() async throws {
        let spy = NoteServiceSpy()
        let sut = NoteEditorViewModel(notes: spy)
        sut.title = "  Padded  "
        sut.body = "Body"

        await sut.save()

        let added = await spy.added
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.title, "Padded", "title must be trimmed on save")
        XCTAssertEqual(sut.title, "Padded")
        XCTAssertFalse(sut.isNewNote)
        XCTAssertFalse(sut.isDirty)
    }

    func testSave_bodyOnlyNote_getsUntitledTitle() async throws {
        let spy = NoteServiceSpy()
        let sut = NoteEditorViewModel(notes: spy)
        sut.body = "Just body"

        await sut.save()

        let added = await spy.added
        XCTAssertEqual(added.first?.title, "Untitled")
    }

    func testSave_unchangedExisting_skipsWrite() async throws {
        let spy = NoteServiceSpy()
        let note = Note(title: "Stable", content: "Same")
        try await spy.update(note)

        let sut = NoteEditorViewModel(noteId: note.id, notes: spy)
        try await waitLoaded(spy)

        await sut.save()

        let updated = await spy.updated
        XCTAssertEqual(updated.count, 1, "only the seed write should have happened")
    }

    func testSave_existingNote_preservesIDAndDate() async throws {
        let spy = NoteServiceSpy()
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 15
        let originalDate = Calendar(identifier: .gregorian).date(from: comps)!
        let note = Note(title: "Before", content: "text", date: originalDate)
        try await spy.update(note)

        let sut = NoteEditorViewModel(noteId: note.id, notes: spy)
        try await waitLoaded(spy)

        sut.title = "After"
        await sut.save()

        let updated = await spy.updated
        XCTAssertEqual(updated.count, 2)
        let saved = updated.last
        XCTAssertEqual(saved?.id, note.id)
        XCTAssertEqual(saved?.date, originalDate, "editing must not bump the note date")
        XCTAssertEqual(saved?.title, "After")
    }

    func testSave_addFails_noteRemainsNew() async throws {
        let spy = NoteServiceSpy()
        await spy.setFailsAddForTest(true)
        let sut = NoteEditorViewModel(notes: spy)
        sut.title = "Doomed"

        await sut.save()

        XCTAssertTrue(sut.isNewNote, "failed add must not pretend the note was persisted")
    }

    // MARK: - Delete

    func testDelete_newNote_isNoOp() async throws {
        let spy = NoteServiceSpy()
        let sut = NoteEditorViewModel(notes: spy)
        sut.title = "Never saved"

        await sut.delete()

        let deleted = await spy.deletedIDs
        XCTAssertTrue(deleted.isEmpty)
    }

    func testDelete_loadedNote_deletesByOriginalID() async throws {
        let spy = NoteServiceSpy()
        let note = Note(title: "Doomed", content: "")
        try await spy.update(note)

        let sut = NoteEditorViewModel(noteId: note.id, notes: spy)
        try await waitLoaded(spy)

        await sut.delete()

        let deleted = await spy.deletedIDs
        XCTAssertEqual(deleted, [note.id])
        let remaining = await spy.notes
        XCTAssertTrue(remaining.isEmpty)
    }

    // MARK: - Autosave (debounced)

    func testOnTextChanged_firesSaveAfterDebounce() async throws {
        let spy = NoteServiceSpy()
        let sut = NoteEditorViewModel(notes: spy)
        sut.title = "Auto"

        sut.onTextChanged()
        try await Task.sleep(for: .milliseconds(1000))

        let added = await spy.added
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.title, "Auto")
    }

    func testOnTextChanged_rapidEdits_coalesceIntoSingleSave() async throws {
        let spy = NoteServiceSpy()
        let sut = NoteEditorViewModel(notes: spy)

        for text in ["a", "ab", "abc"] {
            sut.title = text
            sut.onTextChanged()
            try await Task.sleep(for: .milliseconds(100))
        }
        try await Task.sleep(for: .milliseconds(1000))

        let added = await spy.added
        XCTAssertEqual(added.count, 1, "debounce must collapse bursts into one save")
        XCTAssertEqual(added.first?.title, "abc", "the save must capture the latest text")
    }

    func testOnTextChanged_cleaningContent_cancelsPendingSave() async throws {
        let spy = NoteServiceSpy()
        let sut = NoteEditorViewModel(notes: spy)

        sut.title = "oops"
        sut.onTextChanged()
        sut.title = ""
        sut.onTextChanged()
        try await Task.sleep(for: .milliseconds(1000))

        let added = await spy.added
        XCTAssertTrue(added.isEmpty, "a cancelled pending save must not write empty content")
    }
}
