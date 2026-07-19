//
//  ItemManager.swift
//  MeditateAndNote
//
//  Created by Quasar on 01.12.2025.
//

import Foundation

final actor NoteManager: ItemProvidable, ItemManagable {
    typealias Item = Note
    
    private let repository: NotesRepository
    private(set) var currentItems: [Note] = []
    private(set) var lastError: Error?
    
    init(repository: NotesRepository) {
        self.repository = repository
    }
    
    func refresh() async {
        await refreshFromRemote()
    }
    
    func addItem(_ item: Item) async throws {
        try await repository.saveItem(item, strategy: .hybrid)
        currentItems = try await repository.getItems(strategy: .hybrid)
    }
    
    func deleteItem(_ item: Item) async throws {
        try await repository.deleteItem(id: item.id.uuidString, strategy: .hybrid)
        currentItems = try await repository.getItems(strategy: .hybrid)
    }
    
    func filterItems(query: SearchQuery) async -> [Item] {
        query.text.isEmpty
        ? currentItems
        : currentItems.reversed()
    }
    
    func clearAll() async {
        currentItems.removeAll()
    }
}

private extension NoteManager {
    func refreshFromRemote() async {
        do {
            currentItems = try await repository.getItems(strategy: .remoteFirst)
            lastError = nil
        } catch {
            print("Failed to fetch initial notes: \(error)")
            lastError = error
        }
    }
}
