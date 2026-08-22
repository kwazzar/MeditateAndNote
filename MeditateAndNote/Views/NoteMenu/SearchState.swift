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
    var filteredItems: [Note] = []

    var isSearching: Bool {
        searchText != .all
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
        filteredItems = availableItems.filter { NoteFilter.matches($0, query: query) }
    }
}

extension SearchState {
    func resetSearch() {
        searchText = .all
        updateFilteredItems(for: searchText)
    }
}
