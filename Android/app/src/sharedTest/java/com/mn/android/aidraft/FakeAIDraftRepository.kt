package com.mn.android.aidraft

import com.mn.android.domain.aidraft.AIDraftError
import com.mn.android.domain.aidraft.AIDraftRepository
import com.mn.android.domain.aidraft.AIDraftResult
import com.mn.android.domain.aidraft.AIDraftSession
import com.mn.android.domain.aidraft.AIDraftState
import com.mn.android.domain.aidraft.AIDraftSuggestion
import com.mn.android.domain.note.NoteId
import java.util.UUID

/**
 * The draft path without the model.
 *
 * It mimics what the bridge does: one session per note, the suggestions split
 * into pending and accepted, and an opaque document handed back for the next
 * transition.
 */
class FakeAIDraftRepository(
    private val suggestions: () -> List<AIDraftSuggestion> = {
        listOf(
            AIDraftSuggestion(
                id = UUID.randomUUID().toString(),
                text = "Keep walking slowly",
                rationale = "matches the calm tone",
            ),
        )
    },
) : AIDraftRepository {

    private val sessions = mutableMapOf<NoteId, AIDraftSession>()

    override suspend fun start(noteId: NoteId, instruction: String, context: String): AIDraftResult {
        val session = AIDraftSession(
            id = UUID.randomUUID().toString(),
            noteId = noteId,
            state = AIDraftState.READY,
            error = null,
            suggestions = suggestions(),
            accepted = emptyList(),
            grounded = context.isNotBlank(),
            document = document(),
        )
        sessions[noteId] = session
        return AIDraftResult(session = session, metric = null, error = null)
    }

    override suspend fun stored(noteId: NoteId): AIDraftResult =
        AIDraftResult(session = sessions[noteId], metric = null, error = null)

    override suspend fun accept(session: AIDraftSession, suggestionId: String): AIDraftResult {
        val suggestion = session.suggestions.firstOrNull { it.id == suggestionId }
            ?: return failure()
        return transition(session, session.accepted + suggestion)
    }

    override suspend fun acceptAll(session: AIDraftSession): AIDraftResult =
        transition(session, session.accepted + session.pending)

    override suspend fun reject(session: AIDraftSession, suggestionId: String): AIDraftResult =
        transition(session, session.accepted.filterNot { it.id == suggestionId })

    override suspend fun discard(noteId: NoteId) {
        sessions.remove(noteId)
    }

    private fun transition(
        session: AIDraftSession,
        accepted: List<AIDraftSuggestion>,
    ): AIDraftResult {
        val next = session.copy(accepted = accepted, document = document())
        sessions[session.noteId] = next
        return AIDraftResult(session = next, metric = null, error = null)
    }

    private fun failure() = AIDraftResult(
        session = null,
        metric = null,
        error = AIDraftError.Failed("noContext"),
    )

    private fun document() = "document-${UUID.randomUUID()}"
}
