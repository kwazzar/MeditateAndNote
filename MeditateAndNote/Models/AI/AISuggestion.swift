//
//  AISuggestion.swift
//  MeditateAndNote
//
//  Domain value object: a single suggestion produced by an AI provider.
//  Immutable and compared by value.
//

import Foundation

// MARK: - AISuggestion

struct AISuggestion: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    /// The suggestion text to insert into a note. Guardrailed to a length.
    let text: String
    /// A short human-readable reason ("fits your journaling goal").
    let rationale: String

    init(
        id: UUID = UUID(),
        text: String,
        rationale: String = ""
    ) {
        self.id = id
        self.text = text
        self.rationale = rationale
    }
}
