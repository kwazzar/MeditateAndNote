//
//  NoteInsightsCollection.swift
//  MeditateAndNote
//
//  Domain aggregate over the insight collection.
//  Owns the collection-level invariant: at most one insight per note.
//

import Foundation

struct NoteInsightsCollection: Equatable, Codable, Sendable {
    private var insightsByNoteID: [NoteID: NoteInsight]

    init(insights: [NoteInsight] = []) {
        var map: [NoteID: NoteInsight] = [:]
        for insight in insights {
            let existing = map[insight.noteID]
            if let existing {
                map[insight.noteID] = existing.generatedAt >= insight.generatedAt ? existing : insight
            } else {
                map[insight.noteID] = insight
            }
        }
        self.insightsByNoteID = map
    }

    subscript(noteID: NoteID) -> NoteInsight? {
        insightsByNoteID[noteID]
    }

    /// All insights, newest first.
    var allInsights: [NoteInsight] {
        insightsByNoteID.values.sorted { $0.generatedAt > $1.generatedAt }
    }

    var count: Int { insightsByNoteID.count }

    var isEmpty: Bool { insightsByNoteID.isEmpty }

    mutating func upsert(_ insight: NoteInsight) {
        if let existing = insightsByNoteID[insight.noteID] {
            insightsByNoteID[insight.noteID] =
                existing.generatedAt >= insight.generatedAt ? existing : insight
        } else {
            insightsByNoteID[insight.noteID] = insight
        }
    }

    mutating func remove(noteID: NoteID) {
        insightsByNoteID.removeValue(forKey: noteID)
    }

    mutating func removeAll() {
        insightsByNoteID.removeAll()
    }

    // MARK: - Codable (dictionary with NoteID keys)

    private enum CodingKeys: String, CodingKey {
        case insights
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let insights = try container.decode([NoteInsight].self, forKey: .insights)
        self.init(insights: insights)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(allInsights, forKey: .insights)
    }
}
