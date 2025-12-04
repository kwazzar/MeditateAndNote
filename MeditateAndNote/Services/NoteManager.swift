//
//  ItemManager.swift
//  MeditateAndNote
//
//  Created by Quasar on 01.12.2025.
//

import Foundation

final class NoteManager: ItemProvidable, ItemManagable {
    typealias Item = Note

    private let repository: NotesRepository
    private(set) var currentItems: [Note] = []

    init(repository: NotesRepository) {
        self.repository = repository
        self.currentItems = repository.fetchAll()
    }

    func addItem(_ item: Item) {
        repository.save(item)
        currentItems = repository.fetchAll()
    }

    func deleteItem(_ item: Item) {
        repository.delete(id: item.id)
        currentItems = repository.fetchAll()
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
