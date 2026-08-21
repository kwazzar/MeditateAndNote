//
//  NoteManager.swift
//  MeditateAndNote
//
//  Application Service: orchestrates Note use cases
//

import Foundation

// MARK: - Protocols for ViewModels

protocol NoteProvidable {
    var currentItems: [Note] { get async }
    func filterItems(query: SearchQuery) async -> [Note]
    func refresh() async
}

protocol NoteManagable {
    func addItem(_ item: Note) async throws
    func deleteItem(_ item: Note) async throws
    func clearAll() async
}

// MARK: - Note Manager (Application Service)

final actor NoteManager: NoteProvidable, NoteManagable {
    private let syncCoordinator: NoteSyncCoordinator
    private let noteRepository: NoteRepository
    private(set) var currentItems: [Note] = []
    private(set) var lastError: Error?
    
    init(syncCoordinator: NoteSyncCoordinator, noteRepository: NoteRepository) {
        self.syncCoordinator = syncCoordinator
        self.noteRepository = noteRepository
    }
    
    // MARK: - NoteProvidable
    
    func refresh() async {
        await refreshFromRemote()
    }
    
    func filterItems(query: SearchQuery) async -> [Note] {
        let trimmedQuery = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return currentItems }
        
        return currentItems.filter { note in
            note.title.rawValue.localizedCaseInsensitiveContains(trimmedQuery)
                || note.content.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }
    
    // MARK: - NoteManagable
    
    func addItem(_ item: Note) async throws {
        try await syncCoordinator.save(item, strategy: .hybrid)
        currentItems = try await syncCoordinator.fetchAll(strategy: .hybrid)
        // Streak update now happens via Domain Event → StreakTracker subscriber
    }
    
    func deleteItem(_ item: Note) async throws {
        try await syncCoordinator.delete(item.id, strategy: .hybrid)
        currentItems = try await syncCoordinator.fetchAll(strategy: .hybrid)
    }
    
    func clearAll() async {
        currentItems.removeAll()
    }
    
    // MARK: - Private
    
    private func refreshFromRemote() async {
        do {
            currentItems = try await syncCoordinator.fetchAll(strategy: .remoteFirst)
            lastError = nil
        } catch {
            print("Failed to fetch initial notes: \(error)")
            lastError = error
        }
    }
}

// MARK: - Type Erasure (for ViewModels)

final class AnyNoteManager: NoteProvidable, NoteManagable {
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