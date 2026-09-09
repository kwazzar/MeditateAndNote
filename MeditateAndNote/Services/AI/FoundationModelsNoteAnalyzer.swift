//
//  FoundationModelsNoteAnalyzer.swift
//  MeditateAndNote
//
//  On-device batch analyzer built on Apple's Foundation Models (iOS 26+).
//  Guarded by `canImport` so the project still compiles at its deployment
//  target (17.6); at runtime it falls back to HeuristicNoteAnalyzer whenever
//  the system model is unavailable or generation fails.
//
//  The FoundationModels API surface is isolated here — nothing in Domain or
//  Application touches it.
//

import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

struct FoundationModelsNoteAnalyzer: NoteAnalyzer {
    private let fallback: HeuristicNoteAnalyzer
    private let logger = Logger(subsystem: Config.bundleID, category: "NoteInsights")

    init(fallback: HeuristicNoteAnalyzer = HeuristicNoteAnalyzer()) {
        self.fallback = fallback
    }

    var isAvailable: Bool {
        // Analysis always degrades to the heuristic, so the manager can
        // always schedule a pass; on-device just upgrades its quality.
        true
    }

    func analyze(notes: [Note]) async throws -> [NoteInsight] {
        guard #available(iOS 26.0, *) else {
            return try await fallback.analyze(notes: notes)
        }
        #if canImport(FoundationModels)
        guard systemModelAvailable() else {
            return try await fallback.analyze(notes: notes)
        }
        do {
            return try await generate(notes: notes)
        } catch let error as NoteAnalysisError {
            throw error
        } catch {
            logger.error("Foundation Models analysis failed, using heuristic — \(error.localizedDescription)")
            return try await fallback.analyze(notes: notes)
        }
        #else
        return try await fallback.analyze(notes: notes)
        #endif
    }

    // MARK: - FoundationModels backed implementation

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func systemModelAvailable() -> Bool {
        SystemLanguageModel.default.availability == .available
    }

    /// Batch-analyzes up to 10 notes in a single session. Notes are matched
    /// back by UUID string; anything unparseable falls back per-note to the
    /// heuristic so one bad row never discards the whole batch.
    @available(iOS 26.0, *)
    private func generate(notes: [Note]) async throws -> [NoteInsight] {
        let analyzable = notes.filter { !HeuristicNoteAnalyzer.combinedText(of: $0).isEmpty }
        guard !analyzable.isEmpty else {
            throw NoteAnalysisError.insufficientData
        }
        let batch = Array(analyzable.prefix(10))

        let session = LanguageModelSession(
            model: .default,
            tools: [],
            instructions: Self.systemInstructions
        )
        let response = try await session.respond(to: Self.batchPrompt(for: batch))
        let parsed = Self.parseInsights(from: response.content, notes: batch)
        guard !parsed.isEmpty else {
            return try await fallback.analyze(notes: notes)
        }
        return parsed
    }

    @available(iOS 26.0, *)
    private static var systemInstructions: String {
        """
        You analyze reflective journaling notes. For each note return up to 3 \
        single-word theme labels, a one-sentence summary under 140 characters, \
        and up to 3 lowercase tag suggestions. Never invent personal facts. \
        Reply with a JSON object only: \
        {"insights": [{"noteID": "<uuid>", "themes": ["calm"], "summary": "...", "tags": ["calm"]}]}
        """
    }

    @available(iOS 26.0, *)
    private static func batchPrompt(for notes: [Note]) -> String {
        let blocks = notes.map { note -> String in
            let text = HeuristicNoteAnalyzer.combinedText(of: note)
            return "NOTE \(note.id.rawValue.uuidString):\n\(text.prefix(500))"
        }
        return blocks.joined(separator: "\n\n---\n\n")
    }

    @available(iOS 26.0, *)
    private static func parseInsights(from text: String, notes: [Note]) -> [NoteInsight] {
        guard let data = text.data(using: .utf8),
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
            let summary = (item["summary"] as? String) ?? ""
            let tags = (item["tags"] as? [String]) ?? []
            let insight = NoteInsight(noteID: note.id, themes: themes, summary: summary, suggestedTags: tags)
            if !insight.isEmpty {
                result.append(insight)
            }
        }
        return result
    }
    #endif
}
