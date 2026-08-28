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

    /// Derived view of `availableItems` for the current query — there is no
    /// second copy of the list that could drift out of sync.
    var filteredItems: [Note] {
        searchText == .all
            ? availableItems
            : availableItems.filter { NoteFilter.matches($0, query: searchText) }
    }

    func setAvailableItems(_ items: [Note]) {
        availableItems = items
    }
}

extension SearchState {
    func resetSearch() {
        searchText = .all
    }
}
