//
//  NoteEmbeddingStore.swift
//  MeditateAndNote
//
//  Persistence contract for NoteEmbedding. Follows the per-domain <X>Store
//  shape (NoteInsightStore, AIDraftSessionStore).
//

import Foundation

// MARK: - Store protocol

public protocol NoteEmbeddingStore: Sendable {
    func fetchAll() async throws -> [NoteEmbedding]
    func fetch(noteID: NoteID) async throws -> NoteEmbedding?
    func save(_ embedding: NoteEmbedding) async throws
    func delete(noteID: NoteID) async throws
    func deleteAll() async throws
}

// MARK: - In-Memory Implementation (tests + previews)

public final actor InMemoryNoteEmbeddingStore: NoteEmbeddingStore {

    public init() {}
    private var embeddings: [NoteID: NoteEmbedding] = [:]

    public func fetchAll() async throws -> [NoteEmbedding] {
        Array(embeddings.values)
    }

    public func fetch(noteID: NoteID) async throws -> NoteEmbedding? {
        embeddings[noteID]
    }

    public func save(_ embedding: NoteEmbedding) async throws {
        embeddings[embedding.noteID] = embedding
    }

    public func delete(noteID: NoteID) async throws {
        embeddings.removeValue(forKey: noteID)
    }

    public func deleteAll() async throws {
        embeddings.removeAll()
    }
}
