//
//  NoteEmbeddingStore.swift
//  MeditateAndNote
//
//  Persistence contract for NoteEmbedding. Follows the per-domain <X>Store
//  shape (NoteInsightStore, AIDraftSessionStore).
//

import Foundation

// MARK: - Store protocol

protocol NoteEmbeddingStore: Sendable {
    func fetchAll() async throws -> [NoteEmbedding]
    func fetch(noteID: NoteID) async throws -> NoteEmbedding?
    func save(_ embedding: NoteEmbedding) async throws
    func delete(noteID: NoteID) async throws
    func deleteAll() async throws
}

// MARK: - In-Memory Implementation (tests + previews)

final actor InMemoryNoteEmbeddingStore: NoteEmbeddingStore {
    private var embeddings: [NoteID: NoteEmbedding] = [:]

    func fetchAll() async throws -> [NoteEmbedding] {
        Array(embeddings.values)
    }

    func fetch(noteID: NoteID) async throws -> NoteEmbedding? {
        embeddings[noteID]
    }

    func save(_ embedding: NoteEmbedding) async throws {
        embeddings[embedding.noteID] = embedding
    }

    func delete(noteID: NoteID) async throws {
        embeddings.removeValue(forKey: noteID)
    }

    func deleteAll() async throws {
        embeddings.removeAll()
    }
}