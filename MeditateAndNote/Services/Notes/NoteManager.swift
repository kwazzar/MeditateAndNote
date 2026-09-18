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
    private let localDataSource: any NoteDataSource
    private let eventBus: DomainEventPublisher

    /// The aggregate owns collection-level invariants (one entry per ID,
    /// last-write-wins by date); the manager never holds a bare array.
    private var book = NoteBook()
    var currentNotes: [Note] { book.notes }

    init(local: any NoteDataSource,
         eventBus: DomainEventPublisher = DomainEventBus.shared) {
        self.localDataSource = local
        self.eventBus = eventBus
    }

    // MARK: - NoteProvidable

    func refresh() async {
        do {
            book = NoteBook(notes: try await localDataSource.fetchAll())
        } catch {
            logger.error("Failed to fetch notes — \(error.localizedDescription)")
        }
    }

    func note(with id: NoteID) async throws -> Note? {
        try await localDataSource.fetch(id: id)
    }

    func notes(matching query: SearchQuery) async -> [Note] {
        book.notes.filter { NoteFilter.matches($0, query: query) }
    }

    // MARK: - NoteManageable

    func add(_ note: Note) async throws {
        try await localDataSource.save(note)
        book = NoteBook(notes: try await localDataSource.fetchAll())
        eventBus.publish(.noteCreated(note))
    }

    func update(_ note: Note) async throws {
        try await localDataSource.save(note)
        book = NoteBook(notes: try await localDataSource.fetchAll())
        eventBus.publish(.noteUpdated(note))
    }

    func delete(with id: NoteID) async throws {
        try await localDataSource.delete(id: id)
        book = NoteBook(notes: try await localDataSource.fetchAll())
        eventBus.publish(.noteDeleted(id))
    }
}
