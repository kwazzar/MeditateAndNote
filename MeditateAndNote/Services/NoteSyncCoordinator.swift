//
//  NoteSyncCoordinator.swift
//  MeditateAndNote
//
//  Application Service: orchestrates sync strategies between local/remote data sources
//

import Foundation

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
            return mergeDeduplicating(local: local, remote: remote)
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
            // Write to both, local first for immediate UI feedback
            try await localDataSource.save(note)
            try await remoteDataSource.save(note)
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
            try await remoteDataSource.delete(id: id)
        }
    }

    // MARK: - Private Helpers

    private func mergeDeduplicating(local: [Note], remote: [Note]) -> [Note] {
        var merged = [NoteID: Note]()
        for note in local + remote {
            if let existing = merged[note.id], existing.date >= note.date { continue }
            merged[note.id] = note
        }
        return Array(merged.values)
    }
}