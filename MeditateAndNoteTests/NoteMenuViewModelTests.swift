//
//  NoteMenuViewModelTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 04.09.2026.
//

import XCTest
@testable import MeditateAndNote

@MainActor
final class NoteMenuViewModelTests: XCTestCase {

    private var bus: DomainEventBus!
    private var spy: NoteServiceSpy!

    override func setUp() {
        super.setUp()
        bus = DomainEventBus()
        spy = NoteServiceSpy()
    }

    override func tearDown() {
        bus = nil
        spy = nil
        super.tearDown()
    }

    private func makeNote(_ title: NoteTitle) -> Note {
        Note(title: title, content: "content")
    }

    private func makeSUT() -> NoteMenuViewModel {
        NoteMenuViewModel(notes: spy, eventBus: bus)
    }

    private func seed(_ notes: [Note]) async {
        for note in notes {
            try? await spy.add(note)
        }
    }

    /// Waits until the VM's search state reflects the given seeded count.
    private func waitForItems(_ count: Int, in vm: NoteMenuViewModel) async {
        for _ in 0..<500 {
            if vm.searchState.availableItems.count == count { return }
            await Task.yield()
        }
    }

    // MARK: - loadIfNeeded

    func testLoadIfNeeded_populatesSearchState() async {
        let notes = [makeNote("A"), makeNote("B")]
        await seed(notes)
        let vm = makeSUT()

        await vm.loadIfNeeded()

        XCTAssertEqual(vm.searchState.availableItems, notes)
    }

    func testLoadIfNeeded_loadsExactlyOnce() async {
        let vm = makeSUT()
        await vm.loadIfNeeded()
        let refreshAfterFirst = await spy.refreshCount

        await vm.loadIfNeeded()

        let refreshAfterSecond = await spy.refreshCount
        XCTAssertEqual(refreshAfterFirst, 1)
        XCTAssertEqual(refreshAfterSecond, refreshAfterFirst, "A second load must not re-fetch")
    }

    func testRefreshNotes_reloads() async {
        let vm = makeSUT()
        await vm.loadIfNeeded()
        XCTAssertTrue(vm.searchState.availableItems.isEmpty)

        let note = makeNote("Delayed")
        try? await spy.add(note)
        await vm.refreshNotes()

        XCTAssertEqual(vm.searchState.availableItems, [note])
    }

    // MARK: - deleteNote

    func testDeleteNote_removesFromList() async {
        let notes = [makeNote("A"), makeNote("B"), makeNote("C")]
        await seed(notes)
        let vm = makeSUT()
        await vm.loadIfNeeded()

        await vm.deleteNote(notes[1])

        XCTAssertNil(vm.error)
        XCTAssertEqual(vm.searchState.availableItems, [notes[0], notes[2]])
    }

    func testDeleteNote_failureSetsError() async {
        let note = makeNote("A")
        await seed([note])
        let vm = makeSUT()
        await vm.loadIfNeeded()
        await spy.setFailsDeleteForTest(true)

        await vm.deleteNote(note)

        guard case .deleteFailed(let id) = vm.error else {
            XCTFail("Expected .deleteFailed error, got \(String(describing: vm.error))")
            return
        }
        XCTAssertEqual(id, note.id)
    }

    // MARK: - Domain events

    func testNoteCreatedEvent_reloads() async {
        let vm = makeSUT()
        await vm.loadIfNeeded()

        let note = makeNote("Eventual")
        try? await spy.add(note)
        bus.publish(.noteCreated(note))
        await waitForItems(1, in: vm)

        XCTAssertEqual(vm.searchState.availableItems, [note])
    }

    func testNoteDeletedEvent_reloads() async {
        let notes = [makeNote("A"), makeNote("B")]
        await seed(notes)
        let vm = makeSUT()
        await vm.loadIfNeeded()

        try? await spy.delete(with: notes[0].id)
        bus.publish(.noteDeleted(notes[0].id))
        await waitForItems(1, in: vm)

        XCTAssertEqual(vm.searchState.availableItems, [notes[1]])
    }

    func testMeditationCompletedEvent_doesNotReload() async {
        let note = makeNote("A")
        await seed([note])
        let vm = makeSUT()
        await vm.loadIfNeeded()
        XCTAssertEqual(vm.searchState.availableItems, [note])

        bus.publish(.meditationCompleted(MeditationSession(
            meditationId: MeditationID(rawValue: "m"),
            completedAt: .now,
            duration: SessionDuration(.oneMin)
        )))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(vm.searchState.availableItems, [note])
    }

    // MARK: - Filtering through search state

    func testSearchQuery_filtersAvailableItems() async {
        let notes = [makeNote("Meditation"), makeNote("Shopping")]
        await seed(notes)
        let vm = makeSUT()
        await vm.loadIfNeeded()

        vm.searchState.searchText = SearchQuery(text: "medit")

        XCTAssertEqual(vm.searchState.filteredItems, [notes[0]])
    }
}