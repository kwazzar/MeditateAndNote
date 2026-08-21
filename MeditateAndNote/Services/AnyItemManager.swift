//
//  AnyNoteManager.swift
//  MeditateAndNote
//
//  Created by Quasar on 01.12.2025.
//

import Foundation

// Protocols are defined in NoteManager.swift

//MARK: - AnyNoteManager (Type Erasure for NoteProvidable & NoteManagable)
final class AnyNoteManager: NoteProvidable, NoteManagable {
    private let _currentItems: () async -> [Note]
    private let _itemWith: (NoteID) async throws -> Note?
    private let _filterItems: (SearchQuery) async -> [Note]
    private let _refresh: () async -> Void
    private let _addItem: (Note) async throws -> Void
    private let _updateItem: (Note) async throws -> Void
    private let _deleteItem: (NoteID) async throws -> Void

    init<T: NoteProvidable & NoteManagable>(_ manager: T) {
        _currentItems = { await manager.currentItems }
        _itemWith = { try await manager.item(with: $0) }
        _filterItems = { await manager.filterItems(query: $0) }
        _refresh = { await manager.refresh() }
        _addItem = { try await manager.addItem($0) }
        _updateItem = { try await manager.updateItem($0) }
        _deleteItem = { try await manager.deleteItem(with: $0) }
    }

    var currentItems: [Note] {
        get async { await _currentItems() }
    }

    func item(with id: NoteID) async throws -> Note? {
        try await _itemWith(id)
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

    func updateItem(_ item: Note) async throws {
        try await _updateItem(item)
    }

    func deleteItem(with id: NoteID) async throws {
        try await _deleteItem(id)
    }
}
