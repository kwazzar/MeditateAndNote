//
//  SearchState.swift
//  MeditateAndNote
//
//  Created by Quasar on 28.11.2025.
//

import SwiftUI

//MARK: - SearchState
struct SearchQuery {
    let text: String
}

enum NoteFilter {
    static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func matches(_ note: Note, query: String) -> Bool {
        let trimmedQuery = normalized(query)
        guard !trimmedQuery.isEmpty else { return true }
        return note.title.rawValue.localizedCaseInsensitiveContains(trimmedQuery)
            || note.content.localizedCaseInsensitiveContains(trimmedQuery)
    }
}

@Observable
final class SearchState {
    var searchText: SearchQuery = SearchQuery(text: "")
    var isSearching = false
    var filteredItems: [Note] = []

    private let itemProvider: any NoteProvidable
    private var availableItems: [Note] = []

    init(itemProvider: some NoteProvidable) {
        self.itemProvider = itemProvider
    }

    func setAvailableItems(_ items: [Note]) {
        self.availableItems = items
        self.filteredItems = items
    }

    func updateFilteredItems(for query: SearchQuery) {
        isSearching = !NoteFilter.normalized(query.text).isEmpty
        filteredItems = availableItems.filter { NoteFilter.matches($0, query: query.text) }
    }
}

extension SearchState {
    func resetSearch() {
        searchText = SearchQuery(text: "")
        isSearching = false
        updateFilteredItems(for: SearchQuery(text: ""))
    }
}
