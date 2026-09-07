//
//  AIDraftSessionStore.swift
//  MeditateAndNote
//
//  Persistence contract for AIDraftSession. Follows the per-domain
//  <X>Store/DataSource shape from NotesRepository.swift.
//

import Foundation

// MARK: - Store protocol

protocol AIDraftSessionStore: Sendable {
    func fetchAll() async throws -> [AIDraftSession]
    func fetch(id: UUID) async throws -> AIDraftSession?
    func fetch(noteID: NoteID) async throws -> AIDraftSession?
    func save(_ session: AIDraftSession) async throws
    func delete(id: UUID) async throws
    func delete(noteID: NoteID) async throws
    func deleteAll() async throws
}

// MARK: - In-Memory Implementation (tests + previews)

final actor InMemoryAIDraftSessionStore: AIDraftSessionStore {
    private var sessions: [AIDraftSession]

    init(seed: [AIDraftSession] = []) {
        self.sessions = seed
    }

    func fetchAll() async throws -> [AIDraftSession] {
        sessions
    }

    func fetch(id: UUID) async throws -> AIDraftSession? {
        sessions.first { $0.id == id }
    }

    func fetch(noteID: NoteID) async throws -> AIDraftSession? {
        sessions.first { $0.noteID == noteID }
    }

    func save(_ session: AIDraftSession) async throws {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }

    func delete(id: UUID) async throws {
        sessions.removeAll { $0.id == id }
    }

    func delete(noteID: NoteID) async throws {
        sessions.removeAll { $0.noteID == noteID }
    }

    func deleteAll() async throws {
        sessions.removeAll()
    }
}
