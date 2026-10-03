//
//  NoteTheme.swift
//  MeditateAndNote
//
//  Domain value object: a single detected theme of a note collection.
//  Relevance is clamped to 0...1 at the boundary so no caller can inject
//  an out-of-range score.
//

import Foundation

public struct NoteTheme: Hashable, Codable, Sendable, Comparable {
    /// Human-readable label, trimmed. Empty labels are filtered by NoteInsight.
    public let label: String
    /// Relevance score, always within 0...1.
    public let relevance: Double

    public init(label: String, relevance: Double) {
        self.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if relevance.isNaN {
            self.relevance = 0
        } else {
            self.relevance = min(1, max(0, relevance))
        }
    }

    /// Sorts by relevance descending (most relevant first).
    public static func < (lhs: NoteTheme, rhs: NoteTheme) -> Bool {
        lhs.relevance < rhs.relevance
    }
}
