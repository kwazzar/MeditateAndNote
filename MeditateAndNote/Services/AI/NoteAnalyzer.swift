//
//  NoteAnalyzer.swift
//  MeditateAndNote
//
//  Infrastructure contract for background note analysis. The Domain
//  (NoteInsight aggregate) depends on this protocol only; concrete
//  implementations (heuristic, on-device Foundation Models) are swapped
//  in AppContainer and never leak into ViewModels.
//

import Foundation

// MARK: - Analyzer protocol

protocol NoteAnalyzer: Sendable {
    /// Whether this analyzer can serve requests right now.
    /// The heuristic implementation is always available; the
    /// Foundation Models one only on iOS 26+ with Apple Intelligence.
    /// Synchronous on purpose: availability is a cheap local check, and
    /// keeping it sync keeps call sites (manager, tests) warning-free.
    var isAvailable: Bool { get }

    /// Produce one insight per analyzable note (notes without any text
    /// are skipped). Throws NoteAnalysisError.insufficientData when
    /// nothing is analyzable.
    func analyze(notes: [Note]) async throws -> [NoteInsight]
}
