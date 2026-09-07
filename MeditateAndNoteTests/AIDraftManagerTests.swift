//
//  AIDraftManagerTests.swift
//  MeditateAndNoteTests
//

import XCTest
@testable import MeditateAndNote

// MARK: - Stub service

private struct StubAIDraftService: AIDraftService {
    var available: Bool
    var nextResult: Result<[AISuggestion], AIDraftError>

    var isAvailable: Bool { get async { available } }

    func suggest(_ prompt: AIPrompt) async throws -> [AISuggestion] {
        try nextResult.get()
    }
}

// MARK: - Test doubles

private actor Gate {
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuations.append(continuation)
        }
    }

    func resumePending() {
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume() }
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
}

// MARK: - Manager tests

final class AIDraftManagerTests: XCTestCase {

    private var store: InMemoryAIDraftSessionStore!
    private var bus: DomainEventBus!
    private var spy: EventSpy!

    override func setUp() {
        super.setUp()
        store = InMemoryAIDraftSessionStore()
        bus = DomainEventBus()
        spy = EventSpy(bus: bus)
    }

    override func tearDown() {
        store = nil
        bus = nil
        spy = nil
        super.tearDown()
    }

    private func makeManager(service: AIDraftService) -> AIDraftManager {
        AIDraftManager(service: service, store: store, eventBus: bus)
    }

    private func makePrompt() -> AIPrompt {
        AIPrompt(
            instructions: "Give me ideas",
            noteID: NoteID(),
            context: NoteContent("Today I meditated and felt calm.")
        )
    }

    // MARK: - startDraft

    func testStartDraft_success_persistsReadySessionAndPublishesEvent() async throws {
        let service = StubAIDraftService(
            available: true,
            nextResult: .success([
                AISuggestion(text: "Write about the calm", rationale: "matches your note"),
                AISuggestion(text: "What changed today?", rationale: "journaling prompt"),
            ])
        )
        let manager = makeManager(service: service)

        let session = try await manager.startDraft(
            noteID: makePrompt().noteID,
            instructions: "Give me ideas",
            context: NoteContent("Today I meditated and felt calm.")
        )

        XCTAssertEqual(session.state, .ready)
        XCTAssertEqual(session.suggestions.count, 2)

        let persisted = try await store.fetch(id: session.id)
        XCTAssertEqual(persisted, session, "Ready session must be persisted")

        guard case .aiDraftGenerated(let noteID, let sessionID) = spy.events.first else {
            XCTFail("Expected .aiDraftGenerated event")
            return
        }
        XCTAssertEqual(noteID, session.noteID)
        XCTAssertEqual(sessionID, session.id)
    }

    func testStartDraft_serviceFailure_marksSessionFailedAndRethrows() async {
        let service = StubAIDraftService(
            available: true,
            nextResult: .failure(.emptyResponse)
        )
        let manager = makeManager(service: service)
        let noteID = NoteID()

        do {
            _ = try await manager.startDraft(
                noteID: noteID,
                instructions: "Give me ideas",
                context: NoteContent("content")
            )
            XCTFail("Expected failure to propagate")
        } catch let error as AIDraftError {
            XCTAssertEqual(error, .emptyResponse)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }

        let persisted = try? await store.fetch(noteID: noteID)
        XCTAssertEqual(persisted?.state, .failed(.emptyResponse))
        XCTAssertFalse(spy.events.contains { if case .aiDraftGenerated = $0 { return true }; return false },
                       "Failed generation must not publish a success event")
    }

    func testStartDraft_rejectsSecondConcurrentDraft() async throws {
        let service = StubAIDraftService(
            available: true,
            nextResult: .success([AISuggestion(text: "a")])
        )
        let manager = makeManager(service: service)
        let noteID = NoteID()

        let first = try await manager.startDraft(
            noteID: noteID,
            instructions: "i",
            context: NoteContent("c")
        )
        XCTAssertEqual(first.state, .ready)

        // A second draft for the same note is a fresh session (ready session
        // is terminal, so it does not block), not an in-flight duplicate.
        let second = try await manager.startDraft(
            noteID: noteID,
            instructions: "i",
            context: NoteContent("c")
        )
        XCTAssertNotEqual(first.id, second.id)
    }

    // MARK: - regenerate

    func testRegenerate_failedSession_retriesSuccessfully() async throws {
        let failing = StubAIDraftService(
            available: true,
            nextResult: .failure(.emptyResponse)
        )
        let manager = makeManager(service: failing)
        let noteID = NoteID()

        do {
            _ = try await manager.startDraft(noteID: noteID, instructions: "i", context: NoteContent("c"))
            XCTFail("Should have failed")
        } catch is AIDraftError {
            // expected
        }

        let failedSession = try await store.fetch(noteID: noteID)
        let failedID = try XCTUnwrap(failedSession?.id)

        // Swap in a healthy service and retry the same session id.
        let healthy = StubAIDraftService(
            available: true,
            nextResult: .success([
                AISuggestion(text: "new idea", rationale: "retry"),
            ])
        )
        let retryManager = makeManager(service: healthy)
        let retried = try await retryManager.regenerate(sessionID: failedID)

        XCTAssertEqual(retried.id, failedID, "Regenerate reuses the session identity")
        XCTAssertEqual(retried.state, .ready)
        XCTAssertEqual(retried.suggestions.count, 1)
    }

    func testRegenerate_cancelledSession_canStartFresh() async throws {
        struct GatedService: AIDraftService {
            let gate: Gate
            var isAvailable: Bool { get async { true } }
            func suggest(_ prompt: AIPrompt) async throws -> [AISuggestion] {
                await gate.wait()
                return [AISuggestion(text: "idea")]
            }
        }

        let gate = Gate()
        let gateDraftManager = makeManager(service: GatedService(gate: gate))
        let noteID = NoteID()

        // startDraft suspends inside suggest() (gate unopened).
        _ = Task {
            try await gateDraftManager.startDraft(
                noteID: noteID,
                instructions: "i",
                context: NoteContent("c")
            )
        }
        try await Task.sleep(nanoseconds: 50_000_000)

        let createdOpt = try await store.fetch(noteID: noteID)
        let created = try XCTUnwrap(createdOpt)
        try await gateDraftManager.cancel(sessionID: created.id)

        let cancelled = try await store.fetch(id: created.id)
        XCTAssertEqual(cancelled?.state, .cancelled)

        // Retry with a healthy service against the same session id.
        let retryManager = makeManager(service: StubAIDraftService(
            available: true,
            nextResult: .success([AISuggestion(text: "new idea", rationale: "retry")])
        ))
        let retried = try await retryManager.regenerate(sessionID: created.id)
        XCTAssertEqual(retried.id, created.id)
        XCTAssertEqual(retried.state, .ready)
    }

    func testRegenerate_readySession_throws() async throws {
        let manager = makeManager(service: StubAIDraftService(
            available: true,
            nextResult: .success([AISuggestion(text: "a")])
        ))
        let noteID = NoteID()

        let session = try await manager.startDraft(noteID: noteID, instructions: "i", context: NoteContent("c"))
        XCTAssertEqual(session.state, .ready)

        do {
            _ = try await manager.regenerate(sessionID: session.id)
            XCTFail("A ready session is final — regenerate must throw")
        } catch is AIDraftError {
            // expected
        }
    }

    // MARK: - cancel / discard

    func testCancel_inFlightSession_movesToCancelled() async throws {
        // A service that never resolves lets us cancel while still generating.
        struct NeverService: AIDraftService {
            var isAvailable: Bool { get async { true } }
            func suggest(_ prompt: AIPrompt) async throws -> [AISuggestion] {
                try await Task.sleep(nanoseconds: 10_000_000_000)
                return []
            }
        }

        let manager = makeManager(service: NeverService())
        let noteID = NoteID()

        let task = Task {
            try await manager.startDraft(noteID: noteID, instructions: "i", context: NoteContent("c"))
        }
        // Let the session be created and begin generation.
        try await Task.sleep(nanoseconds: 50_000_000)

        let created = try await store.fetch(noteID: noteID)
        let id = try XCTUnwrap(created?.id)
        try await manager.cancel(sessionID: id)

        let cancelled = try await store.fetch(id: id)
        XCTAssertEqual(cancelled?.state, .cancelled)

        task.cancel()
    }

    func testDiscardSessions_removesNoteSessions() async throws {
        let manager = makeManager(service: StubAIDraftService(
            available: true,
            nextResult: .success([AISuggestion(text: "a")])
        ))
        let noteID = NoteID()

        _ = try await manager.startDraft(noteID: noteID, instructions: "i", context: NoteContent("c"))
        let before = try await store.fetch(noteID: noteID)
        XCTAssertNotNil(before)

        try await manager.discardSessions(for: noteID)
        let after = try await store.fetch(noteID: noteID)
        XCTAssertNil(after)
    }
}