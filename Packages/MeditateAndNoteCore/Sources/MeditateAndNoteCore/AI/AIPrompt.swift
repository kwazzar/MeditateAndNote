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

public struct AIPrompt: Hashable, Codable, Sendable {
    /// The user-facing instruction ("Summarize my mood", "Give me ideas...").
    public let instructions: String
    /// The note whose content this prompt is asking about.
    public let noteID: NoteID
    /// A frozen copy of the note's content at generation time.
    public let context: NoteContent
    /// Upper bound the provider must respect (guardrail, enforced in Entity too).
    public let maxSuggestions: Int

    /// True when the prompt carries note text. Without it the provider can
    /// only ask the user open questions — there is nothing to continue and
    /// nothing worth transferring back into the note.
    public var isGrounded: Bool {
        !context.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(
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

public extension AIPrompt {
    /// Matches the aggregate's invariant: at most 5 suggestions per session.
    static let defaultMaxSuggestions = 5
}
