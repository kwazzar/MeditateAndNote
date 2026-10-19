package com.mn.android.data

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SessionBlobStoreContractTest {

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        SessionBlobStore.configure(context)
        // Isolation: the rows live in a Room database that outlives the test.
        SessionBlobStore.deleteAll()
    }

    @Test
    fun saveAndFetch_persistsPayload() {
        val id = "test-session-fm"
        val payload = """{"completedAt": 1700000000, "data": "test"}"""

        SessionBlobStore.save(id = id, completedAt = 1700000000L, payload = payload)

        val fetched = SessionBlobStore.fetch(start = 0L, end = Long.MAX_VALUE)
        assertTrue(fetched.contains(payload))
    }

    @Test
    fun fetch_returnsEmptyArray_whenNoData() {
        SessionBlobStore.deleteAll()
        val fetched = SessionBlobStore.fetch(start = 0L, end = Long.MAX_VALUE)
        assertEquals("[]", fetched)
    }

    @Test
    fun deleteAll_removesAllSessions() {
        SessionBlobStore.save(
            id = "test-session-delete",
            completedAt = 1700000000L,
            payload = """{"data": "delete-me"}""",
        )
        assertFalse(SessionBlobStore.fetch(start = 0L, end = Long.MAX_VALUE).isEmpty())

        SessionBlobStore.deleteAll()
        // `fetch` returns the JSON array as text, so "empty" is "[]".
        assertEquals("[]", SessionBlobStore.fetch(start = 0L, end = Long.MAX_VALUE))
    }
}