//
//  NoteInsight.swift
//  MeditateAndNote
//
//  Domain entity: background analysis result for a single note.
//  Invariants (enforced in init, never in ViewModels):
//    - at most maxThemes themes, sorted by relevance descending
//    - at most maxTags suggested tags, lowercased/trimmed/deduped
//    - empty theme labels and empty tags are dropped
//

import Foundation

struct NoteInsight: Identifiable, Equatable, Codable, Sendable {
    var id: NoteID { noteID }

    let noteID: NoteID
    let themes: [NoteTheme]
    let summary: String
    let suggestedTags: [String]
    let generatedAt: Date

    init(
        noteID: NoteID,
        themes: [NoteTheme] = [],
        summary: String = "",
        suggestedTags: [String] = [],
        generatedAt: Date = Date()
    ) {
        self.noteID = noteID
        self.themes = Self.normalizedThemes(themes)
        self.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        self.suggestedTags = Self.normalizedTags(suggestedTags)
        self.generatedAt = generatedAt
    }

    // MARK: - Limits

    static let maxThemes = 5
    static let maxTags = 5
    static let maxSummaryLength = 500

    // MARK: - Behavior

    /// True when the insight carries no signal (used to skip persistence).
    var isEmpty: Bool {
        themes.isEmpty && summary.isEmpty && suggestedTags.isEmpty
    }

    /// Returns a copy re-stamped with fresh analysis output, preserving identity.
    func refreshed(themes: [NoteTheme], summary: String, suggestedTags: [String], at date: Date = Date()) -> NoteInsight {
        NoteInsight(
            noteID: noteID,
            themes: themes,
            summary: summary,
            suggestedTags: suggestedTags,
            generatedAt: date
        )
    }

    // MARK: - Normalization (private)

    private static func normalizedThemes(_ themes: [NoteTheme]) -> [NoteTheme] {
        let valid = themes.filter { !$0.label.isEmpty }
        return Array(valid.sorted(by: >).prefix(maxThemes))
    }

    private static func normalizedTags(_ tags: [String]) -> [String] {
        var seen: [String] = []
        for raw in tags {
            let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !tag.isEmpty, !seen.contains(tag) else { continue }
            seen.append(tag)
            if seen.count >= maxTags { break }
        }
        return seen
    }
}
