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

#if canImport(FoundationModels)
import FoundationModels
import MeditateAndNoteCore
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
        switch SystemLanguageModel.default.availability {
        case .available:
            return true
        case .unavailable(let reason):
            // Same DEBUG diagnostic as the draft service: distinguishes a
            // still-downloading model (wait) from an ineligible device (give up).
            logger.info("System model unavailable for analysis: \(String(describing: reason))")
            return false
        }
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
        let batch = Array(analyzable.prefix(NoteInsightRemoteProtocol.maxNotes))

        let session = LanguageModelSession(
            model: .default,
            tools: [],
            instructions: NoteInsightRemoteProtocol.systemInstructions()
        )
        let response = try await session.respond(to: NoteInsightRemoteProtocol.batchPrompt(for: batch))
        let parsed = NoteInsightRemoteProtocol.insights(from: response.content, notes: batch)
        guard !parsed.isEmpty else {
            return try await fallback.analyze(notes: notes)
        }
        return parsed
    }
    #endif
}
