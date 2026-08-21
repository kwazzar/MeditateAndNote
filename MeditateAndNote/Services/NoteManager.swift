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
        currentItems.filter { NoteFilter.matches($0, query: query.text) }
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