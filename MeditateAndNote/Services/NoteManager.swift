//
//  NoteManager.swift
//  MeditateAndNote
//
//  Application Service: orchestrates Note use cases
//

import Foundation

// MARK: - Search Query & Note Filter (domain rules)

struct SearchQuery {
    let text: String
}

enum NoteFilter {
    static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func matches(_ note: Note, query: String) -> Bool {
        let trimmedQuery = normalized(query)
        guard !trimmedQuery.isEmpty else { return true }
        return note.title.rawValue.localizedCaseInsensitiveContains(trimmedQuery)
            || note.content.localizedCaseInsensitiveContains(trimmedQuery)
    }
}

// MARK: - Protocols for ViewModels

protocol NoteProvidable {
    var currentItems: [Note] { get async }
    func item(with id: NoteID) async throws -> Note?
    func filterItems(query: SearchQuery) async -> [Note]
    func refresh() async
}

protocol NoteManagable {
    func addItem(_ item: Note) async throws
    func updateItem(_ item: Note) async throws
    func deleteItem(with id: NoteID) async throws
}

// MARK: - Note Manager (Application Service)

final actor NoteManager: NoteProvidable, NoteManagable {
    private let syncCoordinator: NoteSyncCoordinator
    private let eventBus: DomainEventPublisher
    private(set) var currentItems: [Note] = []
    private(set) var lastError: Error?

    init(syncCoordinator: NoteSyncCoordinator,
         eventBus: DomainEventPublisher = DomainEventBus.shared) {
        self.syncCoordinator = syncCoordinator
        self.eventBus = eventBus
    }

    // MARK: - NoteProvidable

    func refresh() async {
        await refreshFromRemote()
    }

    func item(with id: NoteID) async throws -> Note? {
        try await syncCoordinator.find(id, strategy: .localOnly)
    }

    func filterItems(query: SearchQuery) async -> [Note] {
        currentItems.filter { NoteFilter.matches($0, query: query.text) }
    }

    // MARK: - NoteManagable

    func addItem(_ item: Note) async throws {
        try await syncCoordinator.save(item, strategy: .hybrid)
        currentItems = try await syncCoordinator.fetchAll(strategy: .hybrid)
        eventBus.publish(NoteCreated(note: item))
    }

    func updateItem(_ item: Note) async throws {
        try await syncCoordinator.save(item, strategy: .hybrid)
        currentItems = try await syncCoordinator.fetchAll(strategy: .hybrid)
        eventBus.publish(NoteUpdated(note: item))
    }

    func deleteItem(with id: NoteID) async throws {
        try await syncCoordinator.delete(id, strategy: .hybrid)
        currentItems = try await syncCoordinator.fetchAll(strategy: .hybrid)
        eventBus.publish(NoteDeleted(noteId: id))
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
