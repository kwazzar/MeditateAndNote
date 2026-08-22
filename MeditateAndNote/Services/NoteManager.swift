//
//  NoteManager.swift
//  MeditateAndNote
//
//  Application Service: orchestrates Note use cases
//

import Foundation
import OSLog

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
    var currentNotes: [Note] { get async }
    func note(with id: NoteID) async throws -> Note?
    func notes(matching query: SearchQuery) async -> [Note]
    func refresh() async
}

protocol NoteManagable {
    func add(_ note: Note) async throws
    func update(_ note: Note) async throws
    func delete(with id: NoteID) async throws
}

// MARK: - Errors

enum NoteOperationError: Error {
    case loadFailed(NoteID)
    case saveFailed
    case deleteFailed(NoteID)

    var message: String {
        switch self {
        case .loadFailed: "Не вдалося завантажити нотатку"
        case .saveFailed: "Не вдалося зберегти нотатку"
        case .deleteFailed: "Не вдалося видалити нотатку"
        }
    }
}

// MARK: - Note Manager (Application Service)

final actor NoteManager: NoteProvidable, NoteManagable {
    private let logger = Logger(subsystem: Config.bundleID, category: "NoteManager")
    private let syncCoordinator: NoteSyncCoordinator
    private let eventBus: DomainEventPublisher
    private(set) var currentNotes: [Note] = []

    init(syncCoordinator: NoteSyncCoordinator,
         eventBus: DomainEventPublisher = DomainEventBus.shared) {
        self.syncCoordinator = syncCoordinator
        self.eventBus = eventBus
    }

    // MARK: - NoteProvidable

    func refresh() async {
        await refreshFromRemote()
    }

    func note(with id: NoteID) async throws -> Note? {
        try await syncCoordinator.find(id, strategy: .localOnly)
    }

    func notes(matching query: SearchQuery) async -> [Note] {
        currentNotes.filter { NoteFilter.matches($0, query: query.text) }
    }

    // MARK: - NoteManagable

    func add(_ note: Note) async throws {
        try await syncCoordinator.save(note, strategy: .hybrid)
        currentNotes = try await syncCoordinator.fetchAll(strategy: .hybrid)
        eventBus.publish(NoteCreated(date: note.date))
    }

    func update(_ note: Note) async throws {
        try await syncCoordinator.save(note, strategy: .hybrid)
        currentNotes = try await syncCoordinator.fetchAll(strategy: .hybrid)
        eventBus.publish(NoteUpdated(date: note.date))
    }

    func delete(with id: NoteID) async throws {
        try await syncCoordinator.delete(id, strategy: .hybrid)
        currentNotes = try await syncCoordinator.fetchAll(strategy: .hybrid)
        eventBus.publish(NoteDeleted(noteId: id))
    }

    // MARK: - Private

    private func refreshFromRemote() async {
        do {
            currentNotes = try await syncCoordinator.fetchAll(strategy: .remoteFirst)
        } catch {
            logger.error("Failed to fetch initial notes — \(error.localizedDescription)")
        }
    }
}
