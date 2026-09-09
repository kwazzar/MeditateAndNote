//
//  NoteTheme.swift
//  MeditateAndNote
//
//  Domain value object: a single detected theme of a note collection.
//  Relevance is clamped to 0...1 at the boundary so no caller can inject
//  an out-of-range score.
//

import Foundation

struct NoteTheme: Hashable, Codable, Sendable, Comparable {
    /// Human-readable label, trimmed. Empty labels are filtered by NoteInsight.
    let label: String
    /// Relevance score, always within 0...1.
    let relevance: Double

    init(label: String, relevance: Double) {
        self.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if relevance.isNaN {
            self.relevance = 0
        } else {
            self.relevance = min(1, max(0, relevance))
        }
    }

    /// Sorts by relevance descending (most relevant first).
    static func < (lhs: NoteTheme, rhs: NoteTheme) -> Bool {
        lhs.relevance < rhs.relevance
    }
}
