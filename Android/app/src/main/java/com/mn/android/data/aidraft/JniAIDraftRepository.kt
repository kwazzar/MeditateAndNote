package com.mn.android.data.aidraft

import com.mn.android.data.AIDraftSource
import com.mn.android.domain.aidraft.AIDraftRepository
import com.mn.android.domain.aidraft.AIDraftResult
import com.mn.android.domain.aidraft.AIDraftSession
import com.mn.android.domain.note.NoteId
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * The AI draft path over the JNI bridge.
 *
 * The bridge blocks (it waits for the provider), so every call moves to the IO
 * dispatcher. The failures come back as data - the bridge reports them as an
 * envelope, not as an exception - so the result carries a typed error.
 */
class JniAIDraftRepository(
    private val source: AIDraftSource = AIDraftSource,
) : AIDraftRepository {

    override suspend fun start(
        noteId: NoteId,
        instruction: String,
        context: String,
    ): AIDraftResult = withContext(Dispatchers.IO) {
        source.start(noteId.value, instruction, context)
    }

    override suspend fun stored(noteId: NoteId): AIDraftResult = withContext(Dispatchers.IO) {
        source.stored(noteId.value)
    }

    override suspend fun accept(
        session: AIDraftSession,
        suggestionId: String,
    ): AIDraftResult = withContext(Dispatchers.IO) {
        source.accept(session.document, suggestionId)
    }

    override suspend fun acceptAll(session: AIDraftSession): AIDraftResult =
        withContext(Dispatchers.IO) { source.acceptAllPending(session.document) }

    override suspend fun reject(
        session: AIDraftSession,
        suggestionId: String,
    ): AIDraftResult = withContext(Dispatchers.IO) {
        source.reject(session.document, suggestionId)
    }

    override suspend fun discard(noteId: NoteId) = withContext(Dispatchers.IO) {
        source.discard(noteId.value)
    }
}
