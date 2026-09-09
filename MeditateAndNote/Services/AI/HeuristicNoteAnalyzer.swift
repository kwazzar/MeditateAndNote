//
//  HeuristicNoteAnalyzer.swift
//  MeditateAndNote
//
//  Always-available fallback analyzer: keyword-frequency themes, first-line
//  summaries, top-keyword tag suggestions. Zero system dependencies — runs
//  on iOS 17, in tests and previews. Deterministic, so snapshot tests stay
//  stable without a real AI provider.
//

import Foundation

struct HeuristicNoteAnalyzer: NoteAnalyzer {
    var isAvailable: Bool { true }

    func analyze(notes: [Note]) async throws -> [NoteInsight] {
        let analyzable = notes.filter { !Self.combinedText(of: $0).isEmpty }
        guard !analyzable.isEmpty else {
            throw NoteAnalysisError.insufficientData
        }
        return analyzable.map { Self.insight(for: $0) }
    }

    // MARK: - Per-note insight

    private static func insight(for note: Note) -> NoteInsight {
        let text = combinedText(of: note)
        let frequencies = tokenFrequencies(in: text)
        let top = Array(frequencies.sorted { $0.value > $1.value }.prefix(NoteInsight.maxThemes))
        let peak = top.first?.value ?? 1
        let themes = top.map { NoteTheme(label: $0.key, relevance: Double($0.value) / Double(max(peak, 1))) }
        return NoteInsight(
            noteID: note.id,
            themes: themes,
            summary: Self.summary(of: text),
            suggestedTags: top.map(\.key)
        )
    }

    // MARK: - Text helpers

    static func combinedText(of note: Note) -> String {
        let title = note.title.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = note.content.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let titlePart = (title.isEmpty || title == "Untitled") ? "" : title
        return [titlePart, body].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private static func summary(of text: String, limit: Int = 140) -> String {
        let flattened = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard flattened.count > limit else { return flattened }
        let prefix = String(flattened.prefix(limit))
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]) + "…"
        }
        return prefix + "…"
    }

    // MARK: - Tokenization

    private static func tokenFrequencies(in text: String) -> [String: Int] {
        var counts: [String: Int] = [:]
        for token in tokens(in: text) {
            counts[token, default: 0] += 1
        }
        return counts
    }

    static func tokens(in text: String) -> [String] {
        text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 && !stopwords.contains($0) }
    }

    /// Minimal English stopword set — enough to keep single-word journaling
    /// themes ("calm", "sleep", "anxiety") above filler words.
    private static let stopwords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "from", "have", "has",
        "had", "was", "were", "are", "but", "not", "you", "your", "about",
        "into", "after", "before", "then", "than", "when", "what", "which",
        "who", "how", "why", "can", "could", "should", "would", "there",
        "their", "they", "them", "she", "him", "her", "his", "our", "out",
        "all", "any", "its", "may", "more", "most", "some", "such", "only",
        "over", "also", "just", "like", "get", "got", "make", "made", "feel",
        "feeling", "felt", "today", "yesterday", "really", "very", "much",
        "thing", "things", "lot", "one", "two", "wasn", "didn", "don",
    ]
}
