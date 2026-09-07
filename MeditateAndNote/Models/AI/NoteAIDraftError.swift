//
//  NoteAIDraftError.swift
//  MeditateAndNote
//
//  Typed error enum for the AI draft bounded context. Following the project's
//  per-domain convention (NoteOperationError, etc.): a closed set of cases the
//  UI can switch on, never leaking raw provider strings to the view.
//

import Foundation

enum AIDraftError: String, Error, Equatable, Codable, Sendable {
    /// No valid note context to generate from.
    case noContext
    /// The provider was rate-limited or the daily budget was exceeded.
    case rateLimited
    /// On-device AI is unavailable (older OS, disabled Apple Intelligence) and
    /// no remote fallback is configured.
    case providerUnavailable
    /// The provider returned no usable suggestions.
    case emptyResponse
    /// The context/prompt was too long for the provider.
    case contextTooLong
    /// Generation was cancelled by the user or by a newer generation.
    case cancelled
}
