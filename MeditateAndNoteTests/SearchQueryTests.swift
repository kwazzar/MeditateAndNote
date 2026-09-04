//
//  SearchQueryTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 04.09.2026.
//

import XCTest
@testable import MeditateAndNote

final class SearchQueryTests: XCTestCase {

    // MARK: - Parsing

    func testInit_blankText_becomesAll() {
        XCTAssertEqual(SearchQuery(text: ""), .all)
        XCTAssertEqual(SearchQuery(text: "   "), .all)
        XCTAssertEqual(SearchQuery(text: "\n\t "), .all)
    }

    func testInit_trimsWhitespaceAroundTerm() {
        XCTAssertEqual(SearchQuery(text: "  journal \n"), .term("journal"))
    }

    func testText_allIsEmpty_termExposesRawText() {
        XCTAssertEqual(SearchQuery.all.text, "")
        XCTAssertEqual(SearchQuery(text: " x ").text, "x")
    }

    // MARK: - NoteFilter

    private func note(_ title: String, _ body: String) -> Note {
        Note(title: NoteTitle(title), content: NoteContent(body))
    }

    func testMatches_allAcceptsEverything() {
        XCTAssertTrue(NoteFilter.matches(note("A", "b"), query: .all))
    }

    func testMatches_titleMatchIsCaseInsensitive() {
        XCTAssertTrue(NoteFilter.matches(note("Morning Pages", ""), query: .term("MORNING")))
    }

    func testMatches_contentMatch() {
        XCTAssertTrue(NoteFilter.matches(note("T", "breathing exercise"), query: .term("exercise")))
    }

    func testMatches_nonMatchingTerm() {
        XCTAssertFalse(NoteFilter.matches(note("T", "c"), query: .term("absent")))
    }

    func testMatches_emptyTitleFallsBackToUntitledButContentStillMatches() {
        let n = note("", "secret")
        XCTAssertTrue(NoteFilter.matches(n, query: .term("secret")))
        XCTAssertTrue(NoteFilter.matches(n, query: .term("untitled")), "NoteTitle normalizes empty to Untitled")
    }
}

final class SearchStateTests: XCTestCase {

    private let a = Note(title: "Gratitude", content: "today")
    private let b = Note(title: "Ideas", content: "gratitude app")
    private let c = Note(title: "Random", content: "noise")

    func testFilteredItems_defaultAll_returnsEverything() {
        let state = SearchState()
        state.setAvailableItems([a, b, c])
        XCTAssertEqual(state.filteredItems, [a, b, c])
    }

    func testFilteredItems_derivesFromCurrentQuery() {
        let state = SearchState()
        state.setAvailableItems([a, b, c])

        state.searchText = SearchQuery(text: "gratitude")
        XCTAssertEqual(state.filteredItems, [a, b], "matches title and content")

        state.searchText = SearchQuery(text: "noise")
        XCTAssertEqual(state.filteredItems, [c])
    }

    func testResetSearch_restoresUnfilteredList() {
        let state = SearchState()
        state.setAvailableItems([a, b, c])
        state.searchText = SearchQuery(text: "gratitude")
        XCTAssertEqual(state.filteredItems.count, 2)

        state.resetSearch()

        XCTAssertEqual(state.searchText, .all)
        XCTAssertEqual(state.filteredItems.count, 3)
    }

    func testSetAvailableItems_replacesUnderlyingList() {
        let state = SearchState()
        state.setAvailableItems([a])
        state.setAvailableItems([b, c])
        XCTAssertEqual(state.filteredItems, [b, c])
    }

    func testBlankQuery_behavesAsAll() {
        let state = SearchState()
        state.setAvailableItems([a, b, c])
        state.searchText = SearchQuery(text: "   ")
        XCTAssertEqual(state.filteredItems.count, 3)
    }
}
