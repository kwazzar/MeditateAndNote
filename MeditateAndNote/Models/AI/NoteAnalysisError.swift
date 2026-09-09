//
//  NoteAnalysisError.swift
//  MeditateAndNote
//
//  Typed error enum for the note-insights bounded context. Follows the
//  per-domain convention (NoteOperationError, AIDraftError): a closed set of
//  cases the UI can switch on, never leaking provider strings to the view.
//

import Foundation

enum NoteAnalysisError: String, Error, Equatable, Codable, Sendable {
    /// Not enough note content to produce a meaningful insight.
    case insufficientData
    /// No analyzer is available (e.g. on-device AI off, remote disabled).
    case providerUnavailable
}
