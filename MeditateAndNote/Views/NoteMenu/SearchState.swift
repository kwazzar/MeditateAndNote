//
//  SearchState.swift
//  MeditateAndNote
//
//  Created by Quasar on 28.11.2025.
//

import SwiftUI

//MARK: - SalesUIState
@Observable
final class NotesUIState {
    var isPopupVisible = false
    var showingDailySales = false
    var activeMenuItemID: UUID? = nil
}

//MARK: - SearchState
struct SearchQuery {
    let text: String
}

@Observable
final class SearchState {
    var searchText: SearchQuery = SearchQuery(text: "")
    var isSearching = false
    var filteredItems: [Note] = []

    private let itemProvider: any ItemProvidable
    private var availableItems: [Note] = []

    init(itemProvider: some ItemProvidable) {
        self.itemProvider = itemProvider
    }

    func setAvailableItems(_ items: [Note]) {
        self.availableItems = items
        self.filteredItems = items
    }

    func updateFilteredItems(for query: SearchQuery) {
        let trimmedQuery = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        isSearching = !trimmedQuery.isEmpty

        if trimmedQuery.isEmpty {
            filteredItems = availableItems
        } else {
            filteredItems = availableItems.filter { note in
                note.title.localizedCaseInsensitiveContains(trimmedQuery)
                    || note.content.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }
    }
}

extension SearchState {
    func resetSearch() {
        searchText = SearchQuery(text: "")
        isSearching = false
        updateFilteredItems(for: SearchQuery(text: ""))
    }
}

protocol ItemProtocol: Hashable {
    associatedtype ItemType
    var value: ItemType {get}
}

struct Description: ItemProtocol {
    let value: String

    init(_ value: String? = nil) {
        guard let safeValue = value, !safeValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.value = "no Description"
            return
        }
        self.value = safeValue
    }
}

//struct SearchState_Previews: PreviewProvider {
//    static var previews: some View {
//        SearchState()
//    }
//}
