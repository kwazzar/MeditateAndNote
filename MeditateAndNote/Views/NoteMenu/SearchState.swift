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
    var searchText: SearchQuery = SearchQuery(text: "")
    var filteredItems: [Note] = []

    var isSearching: Bool {
        !NoteFilter.normalized(searchText.text).isEmpty
    }

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
        filteredItems = availableItems.filter { NoteFilter.matches($0, query: query.text) }
    }
}

extension SearchState {
    func resetSearch() {
        searchText = SearchQuery(text: "")
        updateFilteredItems(for: searchText)
    }
}
