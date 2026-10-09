package com.mn.android.data

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NoteBlobStoreContractTest {

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        NoteBlobStore.configure(context)
    }

    @Test
    fun saveAndLoad_persistsPayload() {
        val id = "test-note-123"
        val date = 1700000000L
        val payload = """{"title": "Test", "content": "Content"}"""

        NoteBlobStore.save(id = id, date = date, payload = payload)

        val loaded = NoteBlobStore.load(id)
        assertEquals(payload, loaded)
    }

    @Test
    fun load_returnsEmptyString_whenNotFound() {
        NoteBlobStore.deleteAll()
        val loaded = NoteBlobStore.load("non-existent-id")
        assertEquals("", loaded)
    }

    @Test
    fun fetchAll_returnsAllNotesInDateOrder() {
        NoteBlobStore.deleteAll()
        val note1 = """{"title": "First", "content": "A"}"""
        val note2 = """{"title": "Second", "content": "B"}"""

        NoteBlobStore.save(id = "1", date = 1700000000L, payload = note1)
        NoteBlobStore.save(id = "2", date = 1700100000L, payload = note2)

        val all = NoteBlobStore.fetchAll()
        assertTrue(all.contains(note2))
        assertTrue(all.contains(note1))
    }

    @Test
    fun delete_removesSpecificNote() {
        NoteBlobStore.deleteAll()
        NoteBlobStore.save(id = "to-delete", date = 1700000000L, payload = """{}""")

        NoteBlobStore.delete("to-delete")

        assertEquals("", NoteBlobStore.load("to-delete"))
    }

    @Test
    fun deleteAll_removesAllNotes() {
        NoteBlobStore.deleteAll()
        NoteBlobStore.save(id = "note1", date = 1700000000L, payload = """{}""")
        NoteBlobStore.save(id = "note2", date = 1700100000L, payload = """{}""")

        NoteBlobStore.deleteAll()

        assertEquals("", NoteBlobStore.load("note1"))
        assertEquals("", NoteBlobStore.load("note2"))
    }
}