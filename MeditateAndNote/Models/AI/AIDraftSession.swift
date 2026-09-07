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

enum AIDraftState: Equatable, Codable, Sendable {
    case idle
    case generating
    case ready
    case failed(AIDraftError)
    case cancelled
}

// MARK: - Aggregate

struct AIDraftSession: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let noteID: NoteID
    /// Frozen prompt that produced (or is producing) this session.
    let prompt: AIPrompt
    private(set) var suggestions: [AISuggestion]
    private(set) var state: AIDraftState
    private(set) var createdAt: Date

    init(
        id: UUID = UUID(),
        noteID: NoteID,
        prompt: AIPrompt,
        suggestions: [AISuggestion] = [],
        state: AIDraftState = .idle,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.noteID = noteID
        self.prompt = prompt
        self.suggestions = suggestions
        self.state = state
        self.createdAt = createdAt
    }

    // MARK: - Guards

    /// True when this session may start (or restart) generation. A fresh
    /// `.idle` session can generate; a `.failed` or `.cancelled` session can
    /// be retried. A `.ready` session is final — it already produced results.
    var canGenerate: Bool {
        switch state {
        case .idle, .failed, .cancelled: return true
        case .generating, .ready: return false
        }
    }

    /// True while a generation is pending or in flight. Used to reject a
    /// second concurrent draft for the same note.
    var isInFlight: Bool {
        state == .idle || state == .generating
    }

    // MARK: - Domain transitions (behavior, not bare assignment)

    /// Move a fresh session into generation.
    mutating func beginGeneration() {
        guard canGenerate else { return }
        state = .generating
    }

    /// Deliver a batch of suggestions. Enforces the max-suggestions invariant
    /// and the "no generation after ready/cancelled" invariant.
    mutating func fulfil(with newSuggestions: [AISuggestion]) {
        guard state == .generating else { return }
        suggestions = Array(newSuggestions.prefix(prompt.maxSuggestions))
        state = suggestions.isEmpty ? .failed(.emptyResponse) : .ready
    }

    /// Surface a provider failure.
    mutating func fail(_ error: AIDraftError) {
        guard state == .generating else { return }
        state = .failed(error)
    }

    /// Cancellation is allowed from any non-terminal state.
    mutating func cancel() {
        switch state {
        case .idle, .generating:
            state = .cancelled
        case .ready, .failed, .cancelled:
            break
        }
    }
}
