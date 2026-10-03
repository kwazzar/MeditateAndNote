//
//  SemanticQuery.swift
//  MeditateAndNote
//
//  A semantic search request: the raw query text plus a minimum relevance
//  floor. Emptiness is resolved once, at construction, mirroring SearchQuery.
//

import Foundation

public struct SemanticQuery: Equatable, Sendable {
    public let text: String
    public let minSimilarity: Float

    public init(text: String, minSimilarity: Float = 0.25) {
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.minSimilarity = minSimilarity
    }

    public var isEmpty: Bool { text.isEmpty }
}
