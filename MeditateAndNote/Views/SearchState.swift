//
//  SearchState.swift
//  MeditateAndNote
//
//  Created by Quasar on 28.11.2025.
//

import SwiftUI

//MARK: - SalesUIState
final class NotesUIState: ObservableObject {
    @Published var isPopupVisible = false
    @Published var showingDailySales = false
    @Published var activeMenuItemID: UUID? = nil
}

//MARK: - SearchState
struct SearchQuery {
    let text: String
}

final class SearchState: ObservableObject {
    @Published var searchText: SearchQuery = SearchQuery(text: "")
    @Published var isSearching = false
    @Published var filteredItems: [Note] = []

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
//        if query.text.isEmpty {
            filteredItems = availableItems
//        } else {
//            filteredItems = availableItems.filter { item in
//                item.description.value
//                    .localizedCaseInsensitiveContains(query.text)
//            }
//        }
    }
}

extension SearchState {
    func resetSearch() {
        searchText = SearchQuery(text: "")
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
