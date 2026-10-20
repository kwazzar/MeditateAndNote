//
//  NoteInsightRemoteProtocol.swift
//  MeditateAndNoteCore
//
//  The wire protocol of a note-analysis pass, shared by both platforms.
//
//  It lives in the core for the same reason AIDraftRemoteProtocol does: two
//  analyzers speak it — iOS through the on-device Foundation Models session,
//  Android through the hosted OpenAI-compatible endpoint. Only the transport
//  differs; the instructions, the batch prompt and the parsing must not, or
//  the two apps would ask the model different things and read different
//  answers out of the same response.
//

import Foundation

public enum NoteInsightRemoteProtocol {

    // MARK: - Limits

    /// How many notes one pass covers. The batch is bounded so the prompt
    /// stays small enough for a model to answer it in one go.
    public static let maxNotes = 10

    /// How much of a note the prompt carries.
    public static let maxNoteCharacters = 500

    // MARK: - Prompt

    /// The instructions the model gets before the notes.
    public static func systemInstructions() -> String {
        """
        You analyze reflective journaling notes. For each note return up to 3 \
        single-word theme labels, a one-sentence summary under 140 characters, \
        and up to 3 lowercase tag suggestions. Never invent personal facts. \
        Reply with a JSON object only: \
        {"insights": [{"noteID": "<uuid>", "themes": ["calm"], "summary": "...", "tags": ["calm"]}]}
        """
    }

    /// The user message: the notes, one block each, so the model can match an
    /// answer back to the note it wrote about.
    public static func batchPrompt(for notes: [Note]) -> String {
        let blocks = notes.map { note -> String in
            let text = HeuristicNoteAnalyzer.combinedText(of: note)
            return "NOTE \(note.id.rawValue.uuidString):\n\(text.prefix(maxNoteCharacters))"
        }
        return blocks.joined(separator: "\n\n---\n\n")
    }

    // MARK: - Response

    /// Insights out of the model's answer. A row whose `noteID` is not one of
    /// the analyzed notes is dropped: a model that invents an id is not
    /// describing a note we have.
    ///
    /// Theme relevance is positional — the first theme is the strongest — so
    /// the model only has to name the themes, not score them.
    public static func insights(from content: String, notes: [Note]) -> [NoteInsight] {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["insights"] as? [[String: Any]] else {
            return []
        }
        let byID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id.rawValue.uuidString, $0) })
        var result: [NoteInsight] = []
        for item in items {
            guard let idString = item["noteID"] as? String,
                  let note = byID[idString] else { continue }
            let themes = ((item["themes"] as? [String]) ?? []).prefix(NoteInsight.maxThemes).enumerated().map {
                NoteTheme(label: $0.element, relevance: 1 - Double($0.offset) * 0.15)
            }
            let summary = String(((item["summary"] as? String) ?? "").prefix(NoteInsight.maxSummaryLength))
            let tags = (item["tags"] as? [String]) ?? []
            let insight = NoteInsight(noteID: note.id, themes: themes, summary: summary, suggestedTags: tags)
            if !insight.isEmpty {
                result.append(insight)
            }
        }
        return result
    }
}
