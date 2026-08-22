//
//  NoteManager.swift
//  MeditateAndNote
//
//  Application Service: orchestrates Note use cases
//

import Foundation
import OSLog

// MARK: - Protocols for ViewModels

protocol NoteProvidable {
    var currentNotes: [Note] { get async }
    func note(with id: NoteID) async throws -> Note?
    func notes(matching query: SearchQuery) async -> [Note]
    func refresh() async
}

protocol NoteManageable {
    func add(_ note: Note) async throws
    func update(_ note: Note) async throws
    func delete(with id: NoteID) async throws
}

// MARK: - Errors

enum NoteOperationError: Error {
    case loadFailed(NoteID)
    case saveFailed
    case deleteFailed(NoteID)
}

// MARK: - Note Manager (Application Service)

final actor NoteManager: NoteProvidable, NoteManageable {
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
        currentNotes.filter { NoteFilter.matches($0, query: query) }
    }

    // MARK: - NoteManageable

    func add(_ note: Note) async throws {
        try await syncCoordinator.save(note, strategy: .hybrid)
        currentNotes = try await syncCoordinator.fetchAll(strategy: .hybrid)
        eventBus.publish(.noteCreated(note))
    }

    func update(_ note: Note) async throws {
        try await syncCoordinator.save(note, strategy: .hybrid)
        currentNotes = try await syncCoordinator.fetchAll(strategy: .hybrid)
        eventBus.publish(.noteUpdated(note))
    }

    func delete(with id: NoteID) async throws {
        try await syncCoordinator.delete(id, strategy: .hybrid)
        currentNotes = try await syncCoordinator.fetchAll(strategy: .hybrid)
        eventBus.publish(.noteDeleted(id))
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
