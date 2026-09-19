//
//  SearchState.swift
//  MeditateAndNote
//
//  Created by Quasar on 28.11.2025.
//

import SwiftUI

//MARK: - SearchState
@Observable
final class SearchState {
    var searchText: SearchQuery = .all
    private(set) var availableItems: [Note] = []

    /// Keyword matches for the current query — the primary, synchronous path.
    private(set) var keywordHits: [Note] = []

    /// Semantic-search results for the current query, filled asynchronously
    /// when keyword matching comes up empty (auto mode).
    private(set) var semanticMatches: [Note] = []

    var hasSemanticResults: Bool { !semanticMatches.isEmpty }
    var isSemanticSearching = false

    /// Derived view of `availableItems` for the current query — there is no
    /// second copy of the list that could drift out of sync.
    var filteredItems: [Note] {
        searchText == .all
            ? availableItems
            : availableItems.filter { NoteFilter.matches($0, query: searchText) }
    }

    /// What the list actually shows: keyword hits when present, else semantic
    /// matches (auto mode — semantic only kicks in when it helps).
    var displayedItems: [Note] {
        guard searchText != .all else { return availableItems }
        if !keywordHits.isEmpty { return keywordHits }
        return semanticMatches
    }

    func setAvailableItems(_ items: [Note]) {
        availableItems = items
        recomputeKeywordHits()
    }

    func setSearchText(_ query: SearchQuery) {
        searchText = query
        recomputeKeywordHits()
        semanticMatches = []
    }

    func setSemanticMatches(_ matches: [Note]) {
        semanticMatches = matches
    }

    func setSemanticSearching(_ searching: Bool) {
        isSemanticSearching = searching
    }

    private func recomputeKeywordHits() {
        keywordHits = searchText == .all
            ? []
            : availableItems.filter { NoteFilter.matches($0, query: searchText) }
    }
}

extension SearchState {
    func resetSearch() {
        setSearchText(.all)
    }
}
