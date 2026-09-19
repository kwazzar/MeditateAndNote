//
//  SemanticQuery.swift
//  MeditateAndNote
//
//  A semantic search request: the raw query text plus a minimum relevance
//  floor. Emptiness is resolved once, at construction, mirroring SearchQuery.
//

import Foundation

struct SemanticQuery: Equatable, Sendable {
    let text: String
    let minSimilarity: Float

    init(text: String, minSimilarity: Float = 0.25) {
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.minSimilarity = minSimilarity
    }

    var isEmpty: Bool { text.isEmpty }
}