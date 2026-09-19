//
//  EmbeddingService.swift
//  MeditateAndNote
//
//  Infrastructure contract for on-device text embeddings. Domain types
//  (NoteEmbedding/SemanticQuery) depend on this protocol only, so the concrete
//  NaturalLanguage provider can be swapped without touching domain code.
//

import Foundation

protocol EmbeddingService: Sendable {
    /// Whether an embedding model is available on this device right now.
    var isAvailable: Bool { get }

    /// Embed arbitrary text into a dense vector. Empty text yields an empty
    /// vector (never throws for empty input).
    func embed(_ text: String) async throws -> [Float]
}

// MARK: - Unavailable stub (tests, previews, unsupported languages)

struct DisabledEmbeddingService: EmbeddingService {
    var isAvailable: Bool { false }

    func embed(_ text: String) async throws -> [Float] {
        throw EmbeddingError.modelUnavailable
    }
}

enum EmbeddingError: Error {
    case modelUnavailable
}