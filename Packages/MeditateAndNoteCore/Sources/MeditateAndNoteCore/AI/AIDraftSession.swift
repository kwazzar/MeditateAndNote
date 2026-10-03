//
//  AIDraftSession.swift
//  MeditateAndNote
//
//  Domain aggregate root for a single AI-assisted note-writing draft.
//  Owns the collection-level invariants:
//    - a session is bound to exactly one note (noteID)
//    - at most AIPrompt.maxSuggestions suggestions are ever produced
//    - a ready session can never generate again; failed/cancelled sessions
//      may be retried via beginGeneration
//    - the generation flow is a strict state machine
//

import Foundation

// MARK: - State machine

public enum AIDraftState: Equatable, Codable, Sendable {
    case idle
    case generating
    case ready
    case failed(AIDraftError)
    case cancelled
}

// MARK: - Aggregate

public struct AIDraftSession: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let noteID: NoteID
    /// Frozen prompt that produced (or is producing) this session.
    public let prompt: AIPrompt
    public private(set) var suggestions: [AISuggestion]
    public private(set) var acceptedSuggestions: [AISuggestion]
    public private(set) var state: AIDraftState
    public private(set) var createdAt: Date

    /// Count of suggestions the user has accepted.
    public var acceptedCount: Int { acceptedSuggestions.count }

    /// True when there are accepted suggestions waiting to be transferred.
    public var hasAcceptedSuggestions: Bool { !acceptedSuggestions.isEmpty }

    /// True when the prompt that produced this session carried note text.
    /// An ungrounded session holds questions for the user, not text to write.
    public var isGrounded: Bool { prompt.isGrounded }

    public init(
        id: UUID = UUID(),
        noteID: NoteID,
        prompt: AIPrompt,
        suggestions: [AISuggestion] = [],
        acceptedSuggestions: [AISuggestion] = [],
        state: AIDraftState = .idle,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.noteID = noteID
        self.prompt = prompt
        self.suggestions = suggestions
        self.acceptedSuggestions = acceptedSuggestions
        self.state = state
        self.createdAt = createdAt
    }

    // MARK: - Guards

    /// True when this session may start (or restart) generation. A fresh
    /// `.idle` session can generate; a `.failed` or `.cancelled` session can
    /// be retried. A `.ready` session is final — it already produced results.
    public var canGenerate: Bool {
        switch state {
        case .idle, .failed, .cancelled: return true
        case .generating, .ready: return false
        }
    }

    /// True while a generation is pending or in flight. Used to reject a
    /// second concurrent draft for the same note.
    public var isInFlight: Bool {
        state == .idle || state == .generating
    }

    // MARK: - Domain transitions (behavior, not bare assignment)

    /// Move a fresh session into generation.
    public mutating func beginGeneration() {
        guard canGenerate else { return }
        state = .generating
    }

    /// Deliver a batch of suggestions. Enforces the max-suggestions invariant
    /// and the "no generation after ready/cancelled" invariant.
    /// Resets accepted suggestions since a fresh generation replaces the pool.
    public mutating func fulfil(with newSuggestions: [AISuggestion]) {
        guard state == .generating else { return }
        suggestions = Array(newSuggestions.prefix(prompt.maxSuggestions))
        acceptedSuggestions = []
        state = suggestions.isEmpty ? .failed(.emptyResponse) : .ready
    }

    /// Accept a pending suggestion into the accepted pool.
    /// Returns true if the suggestion was moved from pending to accepted.
    @discardableResult
    public mutating func accept(_ suggestion: AISuggestion) -> Bool {
        guard let index = suggestions.firstIndex(where: { $0.id == suggestion.id }),
              !acceptedSuggestions.contains(where: { $0.id == suggestion.id }) else { return false }
        acceptedSuggestions.append(suggestions[index])
        return true
    }

    /// Remove a suggestion from the accepted pool back to pending.
    @discardableResult
    public mutating func reject(_ suggestion: AISuggestion) -> Bool {
        guard let index = acceptedSuggestions.firstIndex(where: { $0.id == suggestion.id }) else { return false }
        acceptedSuggestions.remove(at: index)
        return true
    }

    /// Accept all pending suggestions.
    public mutating func acceptAll() {
        for suggestion in suggestions where !acceptedSuggestions.contains(where: { $0.id == suggestion.id }) {
            acceptedSuggestions.append(suggestion)
        }
    }

    /// Clear all accepted suggestions.
    public mutating func clearAccepted() {
        acceptedSuggestions = []
    }

    /// Surface a provider failure.
    public mutating func fail(_ error: AIDraftError) {
        guard state == .generating else { return }
        state = .failed(error)
    }

    /// Cancellation is allowed from any non-terminal state.
    public mutating func cancel() {
        switch state {
        case .idle, .generating:
            state = .cancelled
        case .ready, .failed, .cancelled:
            break
        }
    }
    
}
