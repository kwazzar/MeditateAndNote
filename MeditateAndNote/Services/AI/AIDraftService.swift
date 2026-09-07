//
//  AIDraftService.swift
//  MeditateAndNote
//
//  Infrastructure contract for an AI suggestion provider. The Domain
//  (AIDraftSession aggregate) depends on this protocol only; concrete providers
//  (on-device Foundation Models, remote API, disabled stub) are swapped at the
//  AppContainer via AIDraftServiceFactory and never leak into ViewModels.
//

import Foundation

// MARK: - Service protocol

protocol AIDraftService: Sendable {
    /// Whether this provider can serve requests right now.
    var isAvailable: Bool { get async }

    /// Produce suggestions for the given prompt.
    func suggest(_ prompt: AIPrompt) async throws -> [AISuggestion]
}

// MARK: - Disabled stub (older OS, disabled Apple Intelligence, no remote)

/// Always unavailable. Used so the app degrades gracefully instead of crashing
/// when the device doesn't support on-device AI and no remote is configured.
struct DisabledAIDraftService: AIDraftService {
    var isAvailable: Bool { get async { false } }

    func suggest(_ prompt: AIPrompt) async throws -> [AISuggestion] {
        throw AIDraftError.providerUnavailable
    }
}
