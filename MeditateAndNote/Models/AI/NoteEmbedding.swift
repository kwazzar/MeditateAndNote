//
//  NoteEmbedding.swift
//  MeditateAndNote
//
//  Semantic-search building block: an on-device dense vector for one note,
//  plus cosine similarity between vectors. Pure domain — no NaturalLanguage
//  dependency here; the embedding vector is produced by an EmbeddingService.
//

import Foundation

struct NoteEmbedding: Equatable, Sendable {
    let noteID: NoteID
    let vector: [Float]
    /// FNV-1a hash of title + content — lets callers regenerate embeddings
    /// when (and only when) a note's text actually changed.
    let contentHash: UInt64
    let updatedAt: Date

    init(noteID: NoteID, vector: [Float], contentHash: UInt64, updatedAt: Date = .now) {
        self.noteID = noteID
        self.vector = vector
        self.contentHash = contentHash
        self.updatedAt = updatedAt
    }

    static func contentHash(title: String, content: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325 // FNV offset basis (64-bit)
        for byte in "\(title)\u{1F}\(content)".utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3 // FNV prime (64-bit)
        }
        return hash
    }

    /// Cosine similarity in [-1, 1]; 0 when either vector is zero-length.
    func cosineSimilarity(to other: [Float]) -> Float {
        guard vector.count == other.count, !vector.isEmpty else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in vector.indices {
            dot += vector[i] * other[i]
            normA += vector[i] * vector[i]
            normB += other[i] * other[i]
        }
        let denom = (normA.squareRoot()) * (normB.squareRoot())
        return denom > 0 ? dot / denom : 0
    }
}