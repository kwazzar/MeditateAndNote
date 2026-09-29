//
//  AIDraftGroundingUITests.swift
//  MeditateAndNoteUITests
//
//  The ✨ bar is context-dependent: an empty note yields questions with no
//  Accept button, a note with text yields proposals that can be accepted.
//  Drives the real editor so both branches are exercised, not just the
//  domain objects.
//
//  Depends on the on-device model, so the waits are generous. Attachments
//  carry the bar state at each step for manual review.
//

import XCTest

final class AIDraftGroundingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    private func openEmptyEditor() -> XCUIElement {
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 15) { skip.tap() }

        let notes = app.buttons["Notes"]
        XCTAssertTrue(notes.waitForExistence(timeout: 20), "Tab bar should render")
        notes.tap()
        XCTAssertTrue(app.buttons["Add Note"].waitForExistence(timeout: 15), "Should land on note menu")
        app.buttons["Add Note"].tap()

        let title = app.textFields["Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8), "Editor should open")
        return title
    }

    /// The bar's visible text is the model's actual output — print it so the
    /// run log carries what the user sees, not just that a button existed.
    private func dumpBar(_ label: String) {
        let texts = app.staticTexts.allElementsBoundByIndex
            .map(\.label)
            .filter { !$0.isEmpty }
        print("BAR[\(label)] \(texts)")
    }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func generate() {
        let button = app.buttons["aiDraftButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 8), "✨ should exist")
        button.tap()
    }

    /// Waits for the bar to settle on ready and returns its section header.
    @discardableResult
    private func waitForSection(timeout: TimeInterval = 90) -> String? {
        let questions = app.staticTexts["Questions"]
        let proposals = app.staticTexts["Proposals"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if questions.exists { return "Questions" }
            if proposals.exists { return "Proposals" }
            _ = app.buttons["Accept"].waitForExistence(timeout: 2)
            Thread.sleep(forTimeInterval: 1)
        }
        return nil
    }

    func testEmptyNoteAsksQuestionsWithoutAccept() {
        openEmptyEditor()
        generate()

        XCTAssertEqual(waitForSection(), "Questions",
                       "An empty note must get questions, not insertable proposals")
        XCTAssertFalse(app.buttons["Accept"].exists,
                       "Nothing to transfer without context — Accept must stay hidden")
        XCTAssertFalse(app.buttons["Remove"].exists,
                       "A pending row must not offer Remove either — rejecting it was a no-op")
        dumpBar("empty-note-questions")
        attach("empty-note-questions")
    }

    /// Remove used to be offered on pending rows in question mode, where it
    /// silently did nothing. It must only exist on accepted rows — and it
    /// must actually move the suggestion back to pending.
    func testRemoveOnlyActsOnAcceptedSuggestion() {
        openEmptyEditor()
        let body = app.textViews.firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 8))
        body.tap()
        body.typeText("Could not sleep last night, kept replaying the meeting.")

        generate()
        XCTAssertEqual(waitForSection(), "Proposals", "Grounded bar required for the accept path")

        let accept = app.buttons["Accept"].firstMatch
        XCTAssertTrue(accept.waitForExistence(timeout: 10), "Grounded rows offer Accept")
        accept.tap()

        let remove = app.buttons["Remove"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 8), "Accepting must offer Remove")
        remove.tap()
        XCTAssertTrue(remove.waitForNonExistence(timeout: 8),
                      "Remove must move the suggestion back to pending, not sit there")
        XCTAssertTrue(app.buttons["Accept"].firstMatch.exists, "Suggestion is pending again")
        dumpBar("after-remove")
    }

    /// A visible button that cannot act is worse than no button: "Accept All"
    /// used to stay on screen with an empty pending pool, where accepting is
    /// an idempotent no-op.
    func testAcceptAllHidesWhenNothingPending() {
        openEmptyEditor()
        let body = app.textViews.firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 8))
        body.tap()
        body.typeText("Worried about the deadline, wrote a plan instead of panicking.")

        generate()
        XCTAssertEqual(waitForSection(), "Proposals", "Grounded bar required for the accept path")

        let acceptAll = app.buttons["Accept All"].firstMatch
        XCTAssertTrue(acceptAll.waitForExistence(timeout: 10), "Pending rows must offer Accept All")
        acceptAll.tap()

        XCTAssertTrue(acceptAll.waitForNonExistence(timeout: 8),
                      "Accept All must disappear once nothing is pending")
        XCTAssertFalse(app.buttons["Accept"].firstMatch.exists,
                       "No pending rows left, so no Accept buttons")

        // ✨ must regenerate, not replay the cached session: a fresh batch
        // brings pending rows (and Accept All) back.
        generate()
        XCTAssertTrue(acceptAll.waitForExistence(timeout: 90),
                      "A second tap on ✨ must generate a new batch, not replay the cache")
        dumpBar("after-regenerate")
    }

    func testTypingContextSwitchesToProposals() {
        openEmptyEditor()
        generate()
        XCTAssertEqual(waitForSection(), "Questions", "Empty note starts in question mode")

        let body = app.textViews.firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 8))
        body.tap()
        body.typeText("Felt anxious before the review, breathing helped after lunch.")

        // ✨ must not be one-shot: it re-runs against the new context.
        generate()
        XCTAssertEqual(waitForSection(), "Proposals",
                       "With text in the note the bar must switch to proposals")
        XCTAssertTrue(app.buttons["Accept"].waitForExistence(timeout: 10),
                      "Grounded proposals are insertable, so Accept must appear")
        dumpBar("grounded-proposals")
        attach("grounded-proposals")
    }
}
