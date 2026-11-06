package com.mn.android.note

import com.mn.android.domain.note.NoteDraft
import com.mn.android.domain.note.NoteRepository
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The invariants every NoteRepository implementation has to keep, whatever
 * backs it. Assertions stay on behaviour, not on a concrete title or list
 * order: the title normalisation and the ordering belong to the store.
 */
abstract class NoteRepositoryContract {
    protected abstract fun createRepo(): NoteRepository

    @Test fun saveThenGet() = runTest {
        val repo = createRepo()
        val id = repo.newId()
        assertTrue("save must succeed", repo.save(id, NoteDraft("Title", "Content")).isSuccess)
        val result = repo.get(id)
        assertTrue(result.isSuccess)
        val detail = result.getOrNull()
        assertNotNull("the saved note must be readable", detail)
        assertEquals(id, detail!!.id)
    }

    @Test fun deleteRemoves() = runTest {
        val repo = createRepo()
        val id = repo.newId()
        assertTrue(repo.save(id, NoteDraft("t", "c")).isSuccess)
        assertTrue("delete must succeed", repo.delete(id).isSuccess)
        assertNull(repo.get(id).getOrNull())
    }

    @Test fun observeEmitsOnMutation() = runBlocking {
        val repo = createRepo()
        val id = repo.newId()
        withTimeout(5_000) {
            val seen = async(start = CoroutineStart.UNDISPATCHED) {
                repo.observe().first { list -> list.any { it.id == id } }
            }
            repo.save(id, NoteDraft("t", "c"))
            assertTrue(seen.await().any { it.id == id })
        }
    }
}
