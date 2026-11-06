package com.mn.android.aidraft

import com.mn.android.domain.aidraft.AIDraftRepository
import com.mn.android.domain.aidraft.AIDraftState
import com.mn.android.domain.note.NoteId
import java.util.UUID
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The invariants every AIDraftRepository implementation has to keep, whatever
 * backs it. The free-quota rule and the session state machine live in Core -
 * what is checked here is that the answers are carried whole.
 */
abstract class AIDraftRepositoryContract {
    protected abstract fun createRepo(): AIDraftRepository

    @Test fun start_answersWithASessionThatHasSuggestions() = runTest {
        val repo = createRepo()
        val noteId = NoteId(UUID.randomUUID().toString())

        val result = repo.start(noteId, "", "a calm morning")

        assertTrue(result.error?.toString() ?: "", result.ok)
        val session = result.session
        assertNotNull("the generation has to answer with a session", session)
        assertEquals(AIDraftState.READY, session!!.state)
        assertTrue("text in the note means the model continues", session.grounded)
        assertEquals(1, session.suggestions.size)
        assertEquals(1, session.pending.size)
    }

    @Test fun start_asksQuestions_whenThereIsNoContext() = runTest {
        val repo = createRepo()

        val result = repo.start(NoteId(UUID.randomUUID().toString()), "", "")

        assertTrue(result.error?.toString() ?: "", result.ok)
        assertFalse(result.session!!.grounded)
    }

    @Test fun accept_movesTheSuggestionIntoTheAcceptedPool() = runTest {
        val repo = createRepo()
        val started = repo.start(NoteId(UUID.randomUUID().toString()), "", "a calm morning")
        val session = started.session!!
        val suggestionId = session.suggestions.first().id

        val accepted = repo.accept(session, suggestionId)

        assertTrue(accepted.error?.toString() ?: "", accepted.ok)
        assertEquals(1, accepted.session!!.accepted.size)
        assertEquals(0, accepted.session!!.pending.size)
    }

    @Test fun reject_sendsAnAcceptedSuggestionBackToPending() = runTest {
        val repo = createRepo()
        val started = repo.start(NoteId(UUID.randomUUID().toString()), "", "a calm morning")
        val session = started.session!!
        val suggestionId = session.suggestions.first().id
        val accepted = repo.accept(session, suggestionId)

        val rejected = repo.reject(accepted.session!!, suggestionId)

        assertTrue(rejected.error?.toString() ?: "", rejected.ok)
        assertEquals(0, rejected.session!!.accepted.size)
        assertEquals(1, rejected.session!!.pending.size)
    }

    @Test fun acceptAll_acceptsEveryPendingSuggestion() = runTest {
        val repo = createRepo()
        val started = repo.start(NoteId(UUID.randomUUID().toString()), "", "a calm morning")
        val session = started.session!!

        val accepted = repo.acceptAll(session)

        assertTrue(accepted.error?.toString() ?: "", accepted.ok)
        assertEquals(accepted.session!!.suggestions.size, accepted.session!!.accepted.size)
    }

    @Test fun stored_answersWithTheSessionOfTheNote() = runTest {
        val repo = createRepo()
        val noteId = NoteId(UUID.randomUUID().toString())
        val started = repo.start(noteId, "", "a calm morning")

        val stored = repo.stored(noteId)

        assertTrue(stored.error?.toString() ?: "", stored.ok)
        assertNotNull(stored.session)
        assertEquals(started.session!!.id, stored.session!!.id)
        assertEquals(1, stored.session!!.suggestions.size)
    }

    @Test fun discard_dropsTheStoredSession() = runTest {
        val repo = createRepo()
        val noteId = NoteId(UUID.randomUUID().toString())
        repo.start(noteId, "", "a calm morning")

        repo.discard(noteId)

        assertNull(repo.stored(noteId).session)
    }
}
