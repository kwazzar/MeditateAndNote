//
//  ItemManager.swift
//  MeditateAndNote
//
//  Created by Quasar on 01.12.2025.
//

import Foundation

#warning("from NotesService to NoteManager")
final class NoteManager: ItemProvidable, ItemManagable {
    typealias Item = Note
    
    private(set) var currentItems: [Item] = []

    func addItem(_ item: Item) {

    }

    func deleteItem(_ item: Item) {
    }

    func decrementItem(_ item: Item) {
    }

    func filterItems(query: SearchQuery) -> [Item] {
        return query.text.isEmpty
        ? currentItems
        : currentItems.reversed()
//        : currentItems.filter { $0.description.value.lowercased().contains(query.text.lowercased()) }
    }

    func clearAll() {
        currentItems.removeAll()
    }
}
