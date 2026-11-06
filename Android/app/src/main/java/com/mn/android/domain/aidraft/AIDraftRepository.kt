package com.mn.android.domain.aidraft

import com.mn.android.domain.note.NoteId

/**
 * The AI draft path.
 *
 * Request/response: a command answers with the session it produced, never a
 * stream - the model is called once and the session comes back whole. The
 * session state machine and the free-quota rule live in the core package.
 */
interface AIDraftRepository {
    suspend fun start(noteId: NoteId, instruction: String, context: String): AIDraftResult

    /** The session left behind on this note, if any. */
    suspend fun stored(noteId: NoteId): AIDraftResult

    suspend fun accept(session: AIDraftSession, suggestionId: String): AIDraftResult

    suspend fun acceptAll(session: AIDraftSession): AIDraftResult

    suspend fun reject(session: AIDraftSession, suggestionId: String): AIDraftResult

    /** Drops the stored session - the note is gone, so is its draft. */
    suspend fun discard(noteId: NoteId)
}
