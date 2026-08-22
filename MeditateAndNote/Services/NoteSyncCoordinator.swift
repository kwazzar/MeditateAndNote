//
//  NoteSyncCoordinator.swift
//  MeditateAndNote
//
//  Application Service: orchestrates sync strategies between local/remote data sources
//

import Foundation
import OSLog

// MARK: - Sync Strategy

enum SyncStrategy {
    case localOnly
    case remoteOnly
    case localFirst
    case remoteFirst
    case hybrid
}

// MARK: - Sync Coordinator Protocol

protocol NoteSyncCoordinator {
    func fetchAll(strategy: SyncStrategy) async throws -> [Note]
    func find(_ id: NoteID, strategy: SyncStrategy) async throws -> Note?
    func save(_ note: Note, strategy: SyncStrategy) async throws
    func delete(_ id: NoteID, strategy: SyncStrategy) async throws
}

// MARK: - Implementation

final class DefaultNoteSyncCoordinator: NoteSyncCoordinator {
    private let logger = Logger(subsystem: Config.bundleID, category: "NoteSync")
    private let localDataSource: any NoteDataSource
    private let remoteDataSource: any NoteDataSource

    init(local: any NoteDataSource, remote: any NoteDataSource) {
        self.localDataSource = local
        self.remoteDataSource = remote
    }
    
    // MARK: - Fetch All

    func fetchAll(strategy: SyncStrategy) async throws -> [Note] {
        switch strategy {
        case .localOnly:
            return try await localDataSource.fetchAll()

        case .remoteOnly:
            return try await remoteDataSource.fetchAll()

        case .localFirst:
            let local = try await localDataSource.fetchAll()
            return local.isEmpty ? try await remoteDataSource.fetchAll() : local

        case .remoteFirst:
            let remote = try await remoteDataSource.fetchAll()
            return remote.isEmpty ? try await localDataSource.fetchAll() : remote

        case .hybrid:
            let local = try await localDataSource.fetchAll()
            let remote = try await remoteDataSource.fetchAll()
            let outcome = NoteBook.merged(local: local, remote: remote)
            if !outcome.conflicts.isEmpty {
                logger.warning("Sync conflicts resolved last-write-wins: \(outcome.conflicts.count)")
            }
            return outcome.notes
        }
    }

    // MARK: - Find

    func find(_ id: NoteID, strategy: SyncStrategy) async throws -> Note? {
        switch strategy {
        case .localOnly:
            return try await localDataSource.fetch(id: id)

        case .remoteOnly:
            return try await remoteDataSource.fetch(id: id)

        case .localFirst:
            if let local = try await localDataSource.fetch(id: id) {
                return local
            }
            return try await remoteDataSource.fetch(id: id)

        case .remoteFirst:
            if let remote = try await remoteDataSource.fetch(id: id) {
                return remote
            }
            return try await localDataSource.fetch(id: id)

        case .hybrid:
            if let remote = try await remoteDataSource.fetch(id: id) {
                return remote
            }
            return try await localDataSource.fetch(id: id)
        }
    }
    
    // MARK: - Save

    func save(_ note: Note, strategy: SyncStrategy) async throws {
        switch strategy {
        case .localOnly:
            try await localDataSource.save(note)

        case .remoteOnly:
            try await remoteDataSource.save(note)

        case .localFirst, .remoteFirst, .hybrid:
            // Write to both, local first for immediate UI feedback.
            // Remote is best-effort: the note is safe locally and the next
            // hybrid fetch reconciles both sides via mergeDeduplicating.
            try await localDataSource.save(note)
            await bestEffort { try await remoteDataSource.save(note) }
        }
    }

    // MARK: - Delete

    func delete(_ id: NoteID, strategy: SyncStrategy) async throws {
        switch strategy {
        case .localOnly:
            try await localDataSource.delete(id: id)

        case .remoteOnly:
            try await remoteDataSource.delete(id: id)

        case .localFirst, .remoteFirst, .hybrid:
            try await localDataSource.delete(id: id)
            await bestEffort { try await self.remoteDataSource.delete(id: id) }
        }
    }

    // MARK: - Private Helpers

    private func bestEffort(_ operation: () async throws -> Void) async {
        do {
            try await operation()
        } catch {
            logger.error("Remote note sync failed — \(error.localizedDescription); will reconcile on next fetch")
        }
    }
}