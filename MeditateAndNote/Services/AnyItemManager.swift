//
//  AnyItemManager.swift
//  MeditateAndNote
//
//  Created by Quasar on 01.12.2025.
//

import Foundation

protocol ItemProvidable {
    associatedtype Item

    var currentItems: [Item] { get async }
    func filterItems(query: SearchQuery) async -> [Item]
    func refresh() async
}

protocol ItemManagable {
    associatedtype Item

    func addItem(_ item: Item) async throws
    func deleteItem(_ item: Item) async throws
    func clearAll() async
}

//MARK: - AnyItemManager
final class AnyItemManager<Item>: ItemProvidable, ItemManagable {
    private let _currentItems: () async -> [Item]
    private let _filterItems: (SearchQuery) async -> [Item]
    private let _refresh: () async -> Void
    private let _addItem: (Item) async throws -> Void
    private let _deleteItem: (Item) async throws -> Void
    private let _clearAll: () async -> Void

    init<T: ItemProvidable & ItemManagable>(_ manager: T) where T.Item == Item {
        _currentItems = { await manager.currentItems }
        _filterItems = { await manager.filterItems(query: $0) }
        _refresh = { await manager.refresh() }
        _addItem = { try await manager.addItem($0) }
        _deleteItem = { try await manager.deleteItem($0) }
        _clearAll = { await manager.clearAll() }
    }

    var currentItems: [Item] {
        get async { await _currentItems() }
    }

    func filterItems(query: SearchQuery) async -> [Item] {
        await _filterItems(query)
    }
    
    func refresh() async {
        await _refresh()
    }

    func addItem(_ item: Item) async throws {
        try await _addItem(item)
    }

    func deleteItem(_ item: Item) async throws {
        try await _deleteItem(item)
    }

    func clearAll() async {
        await _clearAll()
    }
}
