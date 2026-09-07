//
//  AIPrompt.swift
//  MeditateAndNote
//
//  Domain value object: an immutable request to an AI suggestion provider.
//  Binds instructions to a specific note's context snapshot so the provider
//  never sees a moving target (see race-condition note in AI_NOTES_PLAN.md).
//

import Foundation

// MARK: - AIPrompt

struct AIPrompt: Hashable, Codable, Sendable {
    /// The user-facing instruction ("Summarize my mood", "Give me ideas...").
    let instructions: String
    /// The note whose content this prompt is asking about.
    let noteID: NoteID
    /// A frozen copy of the note's content at generation time.
    let context: NoteContent
    /// Upper bound the provider must respect (guardrail, enforced in Entity too).
    let maxSuggestions: Int

    init(
        instructions: String,
        noteID: NoteID,
        context: NoteContent,
        maxSuggestions: Int = AIPrompt.defaultMaxSuggestions
    ) {
        self.instructions = instructions
        self.noteID = noteID
        self.context = context
        self.maxSuggestions = max(1, min(10, maxSuggestions))
    }
}

extension AIPrompt {
    /// Matches the aggregate's invariant: at most 5 suggestions per session.
    static let defaultMaxSuggestions = 5
}
