//
//  NoteInsightManagerTests.swift
//  MeditateAndNoteTests
//
//  Debounce, throttling, event handling and publishing of NoteInsightManager.
//

import XCTest
@testable import MeditateAndNote

final class NoteInsightManagerTests: XCTestCase {

    private struct StubAnalyzer: NoteAnalyzer {
        var available = true
        var result: Result<[NoteInsight], NoteAnalysisError>?

        var isAvailable: Bool { available }

        func suggestFallback(for notes: [Note]) -> [NoteInsight] {
            notes.map { NoteInsight(noteID: $0.id, summary: "summary") }
        }

        func analyze(notes: [Note]) async throws -> [NoteInsight] {
            if let result { return try result.get() }
            return suggestFallback(for: notes)
        }
    }

    private final class EventSpy: @unchecked Sendable {
        private let lock = NSLock()
        private var _events: [DomainEvent] = []

        init(bus: DomainEventPublisher) {
            bus.subscribe { [weak self] event in
                self?.record(event)
            }
        }

        private func record(_ event: DomainEvent) {
            lock.lock()
            defer { lock.unlock() }
            _events.append(event)
        }

        var events: [DomainEvent] {
            lock.lock()
            defer { lock.unlock() }
            return _events
        }

        var insightsUpdates: [[NoteID]] {
            events.compactMap {
                if case .noteInsightsUpdated(let ids) = $0 { return ids }
                return nil
            }
        }
    }

    private var store: InMemoryNoteInsightStore!
    private var bus: DomainEventBus!
    private var spy: EventSpy!

    override func setUp() {
        super.setUp()
        store = InMemoryNoteInsightStore()
        bus = DomainEventBus()
        spy = EventSpy(bus: bus)
    }

    override func tearDown() {
        store = nil
        bus = nil
        spy = nil
        super.tearDown()
    }

    private func makeManager(
        analyzer: StubAnalyzer = StubAnalyzer(),
        notes: [Note] = [],
        debounce: TimeInterval = 0,
        minInterval: TimeInterval = 0
    ) -> NoteInsightManager {
        NoteInsightManager(
            analyzer: analyzer,
            store: store,
            notesProvider: { notes },
            eventBus: bus,
            debounceInterval: debounce,
            minInterval: minInterval
        )
    }

    private func makeNote(_ text: String) -> Note {
        Note(title: "T", content: NoteContent(text))
    }

    // MARK: - refresh

    func testRefresh_persistsInsightsAndPublishesUpdate() async throws {
        let note = makeNote("calm meditation morning calm")
        let manager = makeManager(notes: [note])

        await manager.refresh(notes: [note])

        let saved = try await store.fetch(noteID: note.id)
        XCTAssertNotNil(saved)
        XCTAssertEqual(spy.insightsUpdates.count, 1)
        XCTAssertEqual(spy.insightsUpdates.first, [note.id])
    }

    func testRefresh_insufficientData_persistsNothingAndPublishesNothing() async throws {
        let manager = makeManager(
            analyzer: StubAnalyzer(result: .failure(.insufficientData)),
            notes: []
        )
        await manager.refresh(notes: [])
        let all = try await store.fetchAll()
        XCTAssertTrue(all.isEmpty)
        XCTAssertTrue(spy.insightsUpdates.isEmpty)
    }

    func testRefresh_skipsEmptyInsights() async throws {
        let note = makeNote("calm calm calm")
        let manager = makeManager(
            analyzer: StubAnalyzer(result: .success([NoteInsight(noteID: note.id)])),
            notes: [note]
        )
        await manager.refresh(notes: [note])
        let all = try await store.fetchAll()
        XCTAssertTrue(all.isEmpty, "Empty insights must not be persisted")
        // A pass still happened, so subscribers reload (and stay empty).
        XCTAssertEqual(spy.insightsUpdates.count, 1)
    }

    func testRefreshNow_throttlesWhenLastPassRecent() async throws {
        let note = makeNote("calm meditation")
        let manager = makeManager(notes: [note], minInterval: 60)
        await manager.refreshNow()
        await manager.refreshNow()
        XCTAssertEqual(spy.insightsUpdates.count, 1, "Second immediate pass must be throttled")
    }

    // MARK: - schedule / events

    func testScheduleRefresh_collapsesRapidEditsIntoOnePass() async throws {
        let note = makeNote("calm meditation morning")
        let manager = makeManager(notes: [note], debounce: 0.05)
        await manager.scheduleRefresh()
        await manager.scheduleRefresh()
        await manager.scheduleRefresh()
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(spy.insightsUpdates.count, 1)
    }

    func testHandleNoteDeleted_removesInsight() async throws {
        let note = makeNote("calm meditation")
        let manager = makeManager(notes: [note])
        await manager.refresh(notes: [note])
        let before = try await store.fetch(noteID: note.id)
        XCTAssertNotNil(before)

        await manager.handle(.noteDeleted(note.id))
        let after = try await store.fetch(noteID: note.id)
        XCTAssertNil(after)
    }

    func testHandleNoteCreated_schedulesDebouncedPass() async throws {
        let note = makeNote("calm meditation morning focus")
        let manager = makeManager(notes: [note], debounce: 0.05)
        await manager.handle(.noteCreated(note))
        try await Task.sleep(nanoseconds: 200_000_000)
        let saved = try await store.fetch(noteID: note.id)
        XCTAssertNotNil(saved)
    }
}
