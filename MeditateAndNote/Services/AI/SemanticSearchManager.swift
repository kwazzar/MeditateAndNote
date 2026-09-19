//
//  SemanticSearchManager.swift
//  MeditateAndNote
//
//  Application layer: on-device semantic search over the note collection.
//  Lazily embeds notes (only missing or text-changed ones), persists the
//  embeddings, then ranks the query's notes by cosine similarity. Reads notes
//  from a provider closure so this actor never depends on the concrete
//  NoteManager type.
//

import Foundation
import OSLog

// MARK: - Protocols for ViewModels

protocol SemanticSearchProvidable {
    /// Whether embeddings can be produced on this device.
    var isAvailable: Bool { get }
    /// Persist embeddings for any note whose embedding is missing or stale.
    func ensureEmbeddings(for notes: [Note]) async
    /// Rank `notes` by relevance to `query`, best first, above the floor.
    func search(matching query: SemanticQuery, in notes: [Note]) async -> [Note]
    /// Drop the embedding for a deleted note.
    func deleteEmbedding(for noteID: NoteID) async
}

// MARK: - Manager

final actor SemanticSearchManager: SemanticSearchProvidable {

    private let logger = Logger(subsystem: Config.bundleID, category: "SemanticSearch")
    private let service: any EmbeddingService
    private let store: any NoteEmbeddingStore

    nonisolated var isAvailable: Bool { service.isAvailable }

    init(service: any EmbeddingService,
         store: any NoteEmbeddingStore) {
        self.service = service
        self.store = store
    }

    func ensureEmbeddings(for notes: [Note]) async {
        guard service.isAvailable else { return }
        var existing: [NoteID: NoteEmbedding] = [:]
        do {
            for embedding in try await store.fetchAll() {
                existing[embedding.noteID] = embedding
            }
        } catch {
            logger.error("Failed to load embeddings — \(error.localizedDescription)")
            return
        }

        for note in notes {
            let hash = NoteEmbedding.contentHash(title: note.title.rawValue,
                                                 content: note.content.rawValue)
            guard existing[note.id]?.contentHash != hash else { continue }

            do {
                let vector = try await service.embed(note.title.rawValue + "\n" + note.content.rawValue)
                guard !vector.isEmpty else { continue }
                try await store.save(NoteEmbedding(noteID: note.id, vector: vector, contentHash: hash))
            } catch {
                logger.error("Embedding failed for \(note.id.rawValue) — \(error.localizedDescription)")
            }
        }
    }

    func search(matching query: SemanticQuery, in notes: [Note]) async -> [Note] {
        guard service.isAvailable, !query.isEmpty else { return [] }
        do {
            let queryVector = try await service.embed(query.text)
            guard !queryVector.isEmpty else { return [] }

            await ensureEmbeddings(for: notes)
            let embeddings: [NoteID: [Float]] = try await {
                var byID: [NoteID: [Float]] = [:]
                for embedding in try await store.fetchAll() {
                    byID[embedding.noteID] = embedding.vector
                }
                return byID
            }()

            let ranked = notes.compactMap { note -> (Note, Float)? in
                guard let vector = embeddings[note.id] else { return nil }
                let score = NoteEmbedding(noteID: note.id, vector: vector, contentHash: 0)
                    .cosineSimilarity(to: queryVector)
                guard score >= query.minSimilarity else { return nil }
                return (note, score)
            }
            return ranked
                .sorted { $0.1 > $1.1 }
                .map(\.0)
        } catch {
            logger.error("Semantic search failed — \(error.localizedDescription)")
            return []
        }
    }

    func deleteEmbedding(for noteID: NoteID) async {
        do {
            try await store.delete(noteID: noteID)
        } catch {
            logger.error("Failed to delete embedding — \(error.localizedDescription)")
        }
    }
}