//
//  AIDraftSessionTests.swift
//  MeditateAndNoteTests
//

import XCTest
@testable import MeditateAndNote

// MARK: - AIPrompt value object

final class AIPromptTests: XCTestCase {

    func testDefaultMaxSuggestions_matchesAggregateInvariant() {
        XCTAssertEqual(AIPrompt.defaultMaxSuggestions, 5)
    }

    func testMaxSuggestions_clampsToLowerBound() {
        let prompt = AIPrompt(
            instructions: "i",
            noteID: NoteID(),
            context: NoteContent("c"),
            maxSuggestions: 0
        )
        XCTAssertEqual(prompt.maxSuggestions, 1)
    }

    func testMaxSuggestions_clampsToUpperBound() {
        let prompt = AIPrompt(
            instructions: "i",
            noteID: NoteID(),
            context: NoteContent("c"),
            maxSuggestions: 11
        )
        XCTAssertEqual(prompt.maxSuggestions, 10)
    }

    func testMaxSuggestions_respectsValueInRange() {
        let prompt = AIPrompt(
            instructions: "i",
            noteID: NoteID(),
            context: NoteContent("c"),
            maxSuggestions: 3
        )
        XCTAssertEqual(prompt.maxSuggestions, 3)
    }

    func testContext_isFrozenSnapshot_notLinkedToSource() {
        var content = NoteContent("snapshot")
        let prompt = AIPrompt(
            instructions: "i",
            noteID: NoteID(),
            context: content,
            maxSuggestions: 2
        )
        content = NoteContent("changed")
        XCTAssertEqual(prompt.context.rawValue, "snapshot")
    }
}

// MARK: - AIDraftSession aggregate

final class AIDraftSessionTests: XCTestCase {

    private func makePrompt(_ max: Int = 5) -> AIPrompt {
        AIPrompt(
            instructions: "Give me ideas",
            noteID: NoteID(),
            context: NoteContent("Today I felt..."),
            maxSuggestions: max
        )
    }

    private func makeSession() -> AIDraftSession {
        AIDraftSession(noteID: NoteID(), prompt: makePrompt())
    }

    private func makeSession(max: Int) -> AIDraftSession {
        AIDraftSession(noteID: NoteID(), prompt: makePrompt(max))
    }

    func testInit_promptAndNoteBound() {
        let noteID = NoteID()
        let prompt = makePrompt()
        let session = AIDraftSession(noteID: noteID, prompt: prompt)

        XCTAssertEqual(session.noteID, noteID)
        XCTAssertEqual(session.prompt, prompt)
        XCTAssertEqual(session.state, .idle)
        XCTAssertTrue(session.suggestions.isEmpty)
    }

    // MARK: canGenerate / isInFlight

    func testCanGenerate_idleSession() {
        XCTAssertTrue(makeSession().canGenerate)
        XCTAssertTrue(makeSession().isInFlight)
    }

    func testCanGenerate_readySessionIsFinal() {
        var session = makeSession()
        session.beginGeneration()
        session.fulfil(with: [AISuggestion(text: "a")])

        XCTAssertFalse(session.canGenerate, "A ready session must never generate again")
        XCTAssertFalse(session.isInFlight)
    }

    func testCanGenerate_failedSessionCanRetry() {
        var session = makeSession()
        session.beginGeneration()
        session.fail(.emptyResponse)

        XCTAssertTrue(session.canGenerate, "A failed session must be retryable")
    }

    func testCanGenerate_cancelledSessionCanRetry() {
        var session = makeSession()
        session.beginGeneration()
        session.cancel()

        XCTAssertTrue(session.canGenerate, "A cancelled session must be retryable")
    }

    // MARK: beginGeneration

    func testBeginGeneration_movesIdleToGenerating() {
        var session = makeSession()
        session.beginGeneration()
        XCTAssertEqual(session.state, .generating)
        XCTAssertTrue(session.isInFlight)
    }

    func testBeginGeneration_isIdempotent_forGenerating() {
        var session = makeSession()
        session.beginGeneration()
        session.beginGeneration()
        XCTAssertEqual(session.state, .generating)
    }

    func testBeginGeneration_ignored_forReady() {
        var session = makeSession()
        session.beginGeneration()
        session.fulfil(with: [AISuggestion(text: "a")])
        session.beginGeneration()
        XCTAssertEqual(session.state, .ready, "Ready is terminal — must not restart")
    }

    func testBeginGeneration_ignored_forInFlightRetryDuringFailure() {
        var session = makeSession()
        session.cancel()
        session.beginGeneration()
        XCTAssertEqual(session.state, .generating, "Retry from cancelled moves to generating")
    }

    // MARK: fulfil

    func testFulfil_deliversSuggestions_upToMax() {
        var session = makeSession()
        session.beginGeneration()
        let many = (0..<20).map { AISuggestion(text: "s\($0)") }
        session.fulfil(with: many)

        XCTAssertEqual(session.state, .ready)
        XCTAssertEqual(session.suggestions.count, AIPrompt.defaultMaxSuggestions)
    }

    func testFulfil_respectsPromptMax() {
        var session = makeSession(max: 2)
        session.beginGeneration()
        session.fulfil(with: [AISuggestion(text: "a"), AISuggestion(text: "b"), AISuggestion(text: "c")])

        XCTAssertEqual(session.suggestions.count, 2, "must never exceed the prompt's maxSuggestions")
    }

    func testFulfil_emptyResult_failsWithEmptyResponse() {
        var session = makeSession()
        session.beginGeneration()
        session.fulfil(with: [])

        XCTAssertEqual(session.state, .failed(.emptyResponse))
    }

    func testFulfil_ignored_unlessGenerating() {
        var session = makeSession()
        session.fulfil(with: [AISuggestion(text: "a")])
        XCTAssertEqual(session.state, .idle, "Suggestions before generation are illegal")
        XCTAssertTrue(session.suggestions.isEmpty)
    }

    // MARK: fail

    func testFail_surfacesError() {
        var session = makeSession()
        session.beginGeneration()
        session.fail(.rateLimited)
        XCTAssertEqual(session.state, .failed(.rateLimited))
    }

    func testFail_ignored_unlessGenerating() {
        var session = makeSession()
        session.fail(.providerUnavailable)
        XCTAssertEqual(session.state, .idle)
    }

    // MARK: cancel

    func testCancel_fromIdle() {
        var session = makeSession()
        session.cancel()
        XCTAssertEqual(session.state, .cancelled)
        XCTAssertFalse(session.isInFlight)
    }

    func testCancel_fromGenerating() {
        var session = makeSession()
        session.beginGeneration()
        session.cancel()
        XCTAssertEqual(session.state, .cancelled)
    }

    func testCancel_ignored_forReady() {
        var session = makeSession()
        session.beginGeneration()
        session.fulfil(with: [AISuggestion(text: "a")])
        session.cancel()
        XCTAssertEqual(session.state, .ready, "Ready results are final — cancel must not discard them")
    }

    func testCancel_ignored_forCancelled() {
        var session = makeSession()
        session.cancel()
        session.cancel()
        XCTAssertEqual(session.state, .cancelled)
    }
}