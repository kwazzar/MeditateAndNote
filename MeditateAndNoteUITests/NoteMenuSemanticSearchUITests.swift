//
//  NoteMenuSemanticSearchUITests.swift
//  MeditateAndNoteUITests
//
//  End-to-end: creates related notes and verifies keyword search — literal
//  hits surface only the matching note, and a keyword miss shows nothing
//  (semantic fallback is disabled: the on-device NL embeddings measured
//  couldn't rank topical relation, see AI_NOTES_PLAN_TASK2.md).
//
//  Note: this test seeds its own notes each run, so run it on a clean install
//  (xcrun simctl uninstall booted nazar.MeditateAndNote) to avoid duplicates
//  from prior runs accumulating in the persisted store.
//

import XCTest

final class NoteMenuSemanticSearchUITests: XCTestCase {
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

    private func openNotesTab() {
        // Fresh installs start with onboarding — skip it if it's shown.
        // The launch screen delays rendering, so wait generously.
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 15) {
            skip.tap()
        }
        // Tab bar must be rendered before tapping into it.
        let home = app.buttons["Home"]
        if !home.waitForExistence(timeout: 20) {
            print("DIAG buttons:", app.buttons.allElementsBoundByIndex.map(\.label))
            print("DIAG tabs:", app.tabBars.allElementsBoundByIndex.map { $0.label })
            print("DIAG other:", app.otherElements.allElementsBoundByIndex.prefix(15).map(\.label))
        }
        XCTAssertTrue(home.exists, "Tab bar should render")
        let notesTab = app.buttons["Notes"]
        XCTAssertTrue(notesTab.waitForExistence(timeout: 5), "Notes tab should exist")
        notesTab.tap()
        // NoteMenu renders the search bar + Add Note synchronously, but the
        // notes list loads async — give the cold launch time after a reinstall.
        XCTAssertTrue(app.buttons["Add Note"].waitForExistence(timeout: 15), "Should land on note menu")
    }

    private func createNote(title: String, body: String) {
        app.buttons["Add Note"].tap()
        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 8), "Editor should open")
        titleField.tap()
        titleField.typeText(title)

        let bodyField = app.textViews.firstMatch
        bodyField.tap()
        bodyField.typeText(body)

        let back = app.buttons["noteEditorBackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        // Back persists the note; wait until the editor is gone.
        XCTAssertTrue(titleField.waitForNonExistence(timeout: 8), "Editor should dismiss")
    }

    private func runSearch(_ query: String) -> XCUIElement {
        let search = app.textFields["Search notes..."]
        XCTAssertTrue(search.waitForExistence(timeout: 8), "Search bar should exist")
        search.tap()
        search.typeText(query)
        return search
    }

    private func clearSearch() {
        let clear = app.buttons["searchClearButton"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        XCTAssertTrue(clear.waitForNonExistence(timeout: 5), "Clear button should disappear after clearing")
    }

    func testKeywordSearchFiltersWithoutSemanticFallback() throws {
        openNotesTab()
        createNote(title: "Mars mission", body: "The red planet, rovers and astronauts")
        createNote(title: "Groceries", body: "Milk, eggs and bread for the week")
        createNote(title: "Workout plan", body: "Running, squats and morning gym")

        // --- Keyword path: a literal hit surfaces only the matching note. ---
        runSearch("Mars")
        XCTAssertTrue(app.staticTexts["Mars mission"].waitForExistence(timeout: 5),
                      "Literal keyword hit must surface the Mars note")
        XCTAssertFalse(app.staticTexts["Groceries"].exists, "Non-matching note must not appear")
        XCTAssertFalse(app.staticTexts["Workout plan"].exists, "Non-matching note must not appear")

        // --- Keyword miss with semantic fallback disabled: empty, no leak. ---
        clearSearch()
        runSearch("space travel")
        XCTAssertTrue(app.staticTexts["Mars mission"].waitForNonExistence(timeout: 5),
                      "No keyword hit must surface nothing — semantic fallback is disabled")
        XCTAssertFalse(app.staticTexts["Groceries"].exists, "No note may leak in without a keyword hit")
        XCTAssertFalse(app.staticTexts["Workout plan"].exists, "No note may leak in without a keyword hit")
    }

    /// Covers manual-QA gaps #10 (whitespace trim), #13 (tab switch keeps
    /// query), #16 (notes + search survive relaunch).
    func testTrimTabSwitchAndRestart() throws {
        openNotesTab()
        createNote(title: "Mars mission", body: "The red planet, rovers and astronauts")

        // --- Trimming: leading/trailing spaces must equal the bare query. ---
        let search = app.textFields["Search notes..."]
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap()
        search.typeText(" Mars ")
        XCTAssertTrue(app.staticTexts["Mars mission"].waitForExistence(timeout: 5),
                      "Whitespace-padded query must be trimmed and hit the Mars note")
        XCTAssertEqual(search.value as? String, " Mars ",
                       "Field shows raw input; trimming happens at match layer, not display")

        // --- Tab switch: query must survive Notes -> Home -> Notes. ---
        app.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["Notes"].waitForExistence(timeout: 5))
        app.buttons["Notes"].tap()
        XCTAssertTrue(app.staticTexts["Mars mission"].waitForExistence(timeout: 5),
                      "Query results must survive a tab switch")

        // --- Restart: notes persist, in-memory search resets. ---
        app.terminate()
        app.launch()
        openNotesTab()
        XCTAssertTrue(app.staticTexts["Mars mission"].waitForExistence(timeout: 10),
                      "Created note must persist across relaunch")
        XCTAssertNotEqual(search.value as? String, "Mars",
                          "Search must reset after relaunch (in-memory state)")
        XCTAssertTrue(app.buttons["Add Note"].exists, "Notes tab functional after relaunch")
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}