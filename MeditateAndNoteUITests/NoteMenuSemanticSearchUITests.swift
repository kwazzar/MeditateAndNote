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

    private func openEditorAndBack(back: XCUIElement) {
        app.buttons["Add Note"].tap()
        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 8), "Editor should open")
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(titleField.waitForNonExistence(timeout: 8), "Editor should dismiss")
    }

    private func untitledRowCount() -> Int {
        app.staticTexts.matching(NSPredicate(format: "label == %@", "Untitled")).count
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

    /// New-save guard: an all-blank or whitespace-only note must not persist;
    /// a body-only note still saves as "Untitled" (existing behavior).
    func testEmptyNoteNotSaved() {
        openNotesTab()
        let back = app.buttons["noteEditorBackButton"]

        let before = untitledRowCount()
        openEditorAndBack(back: back)
        XCTAssertEqual(untitledRowCount(), before,
                       "An all-blank note must not be persisted")

        app.buttons["Add Note"].tap()
        let titleField = app.textFields["Title"]
        let bodyField = app.textViews.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 8))
        titleField.tap()
        titleField.typeText("   ")
        bodyField.tap()
        bodyField.typeText("   ")
        back.tap()
        XCTAssertTrue(titleField.waitForNonExistence(timeout: 8))
        XCTAssertEqual(untitledRowCount(), before,
                       "Whitespace-only input must still be treated as empty")

        // Control: a body-only note DOES save as "Untitled".
        app.buttons["Add Note"].tap()
        XCTAssertTrue(titleField.waitForExistence(timeout: 8))
        bodyField.tap()
        bodyField.typeText("just body")
        back.tap()
        XCTAssertTrue(titleField.waitForNonExistence(timeout: 8))
        XCTAssertEqual(untitledRowCount(), before + 1,
                       "Body-only note must still save with the 'Untitled' title")
    }

    /// Manual-QA #14, made deterministic: renaming a note must update what
    /// keyword search returns (old title stops matching, new one matches).
    func testRenameNoteUpdatesSearch() {
        openNotesTab()
        // Unique per run — repeated test runs persist notes, so a fixed title
        // would leave duplicate rows that keep matching the old query.
        let stamp = String(UUID().uuidString.prefix(6))
        let original = "QA Edit \(stamp)"
        let renamed = "QA Renamed \(stamp)"
        createNote(title: original, body: "words to find")

        // Search narrows the list so the card sits at the top — no scroll dance.
        runSearch(original)
        XCTAssertTrue(tapReadButton(onRowWith: original), "Should open the card to rename")

        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 8), "Editor should open existing note")

        XCTAssertTrue(replaceViaCommonPrefix(in: titleField, from: original, to: renamed), "Should replace the title")
        let back = app.buttons["noteEditorBackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(titleField.waitForNonExistence(timeout: 8), "Editor should dismiss")

        // The still-active old query must now match nothing.
        XCTAssertTrue(app.staticTexts[original].waitForNonExistence(timeout: 5),
                      "Old title must stop matching after rename")
        XCTAssertFalse(app.staticTexts[renamed].exists,
                       "Renamed card must not show under the old-title query")

        clearSearch()
        runSearch(renamed)
        XCTAssertTrue(app.staticTexts[renamed].waitForExistence(timeout: 10),
                      "New title must match after rename")
    }

    /// Replaces an existing value by keeping the shared prefix and deleting only
    /// the tail, so the field is never empty mid-edit. (An empty title is
    /// normalized to "Untitled" by the editor's autosave, corrupting the rename.)
    private func replaceViaCommonPrefix(in field: XCUIElement, from old: String, to new: String) -> Bool {
        let keep = old.commonPrefix(with: new).count
        field.tap()
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count - keep))
        field.typeText(String(new.dropFirst(keep)))
        return true
    }

    /// Taps the card's "Read" button on the row whose title matches, scrolling
    /// the lazy list until the row materializes and becomes hittable.
    private func tapReadButton(onRowWith title: String, attempts: Int = 6) -> Bool {
        let titlePredicate = NSPredicate(format: "label == %@", title)
        let readPredicate = NSPredicate(format: "label == 'Read'")
        for _ in 0..<attempts {
            guard let anchor = app.staticTexts.matching(titlePredicate)
                .allElementsBoundByIndex
                .first(where: \.isHittable) else {
                app.swipeUp()
                continue
            }
            if let button = app.buttons.matching(readPredicate)
                .allElementsBoundByIndex
                .first(where: { abs($0.frame.midY - anchor.frame.midY) < 10 && $0.isHittable }) {
                button.tap()
                return true
            }
            app.swipeUp()
        }
        return false
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}