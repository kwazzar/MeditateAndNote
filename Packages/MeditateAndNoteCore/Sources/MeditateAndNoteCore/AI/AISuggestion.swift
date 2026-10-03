//
//  AISuggestion.swift
//  MeditateAndNote
//
//  Domain value object: a single suggestion produced by an AI provider.
//  Immutable and compared by value.
//

import Foundation

// MARK: - AISuggestion

public struct AISuggestion: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    /// The suggestion text to insert into a note. Guardrailed to a length.
    public let text: String
    /// A short human-readable reason ("fits your journaling goal").
    public let rationale: String

    public init(
        id: UUID = UUID(),
        text: String,
        rationale: String = ""
    ) {
        self.id = id
        self.text = text
        self.rationale = rationale
    }
}
