//
//  AnyItemManager.swift
//  MeditateAndNote
//
//  Created by Quasar on 01.12.2025.
//

import Foundation

// Protocols are defined in NoteManager.swift

//MARK: - AnyItemManager (Type Erasure for NoteProvidable & NoteManagable)
final class AnyItemManager: NoteProvidable, NoteManagable {
    private let _currentItems: () async -> [Note]
    private let _filterItems: (SearchQuery) async -> [Note]
    private let _refresh: () async -> Void
    private let _addItem: (Note) async throws -> Void
    private let _deleteItem: (Note) async throws -> Void
    private let _clearAll: () async -> Void

    init<T: NoteProvidable & NoteManagable>(_ manager: T) {
        _currentItems = { await manager.currentItems }
        _filterItems = { await manager.filterItems(query: $0) }
        _refresh = { await manager.refresh() }
        _addItem = { try await manager.addItem($0) }
        _deleteItem = { try await manager.deleteItem($0) }
        _clearAll = { await manager.clearAll() }
    }

    var currentItems: [Note] {
        get async { await _currentItems() }
    }

    func filterItems(query: SearchQuery) async -> [Note] {
        await _filterItems(query)
    }
    
    func refresh() async {
        await _refresh()
    }

    func addItem(_ item: Note) async throws {
        try await _addItem(item)
    }

    func deleteItem(_ item: Note) async throws {
        try await _deleteItem(item)
    }

    func clearAll() async {
        await _clearAll()
    }
}