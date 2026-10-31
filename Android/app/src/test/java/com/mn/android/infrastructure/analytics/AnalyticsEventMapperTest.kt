package com.mn.android.infrastructure.analytics

import com.mn.android.domain.events.DomainEvent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AnalyticsEventMapperTest {

    @Test
    fun `note events map to stable names without ids`() {
        assertEquals("note_created", AnalyticsEventMapper.from(DomainEvent.NoteCreated("note-1"))?.name)
        assertEquals("note_updated", AnalyticsEventMapper.from(DomainEvent.NoteUpdated("note-1"))?.name)
        assertEquals("note_deleted", AnalyticsEventMapper.from(DomainEvent.NoteDeleted("note-1"))?.name)
    }

    @Test
    fun `meditation completion maps without payload`() {
        val event = AnalyticsEventMapper.from(DomainEvent.MeditationCompleted)
        assertEquals("meditation_completed", event?.name)
        assertTrue(event!!.params.isEmpty())
    }

    @Test
    fun `event names stay within firebase limit`() {
        val events = listOf(
            DomainEvent.NoteCreated("note-1"),
            DomainEvent.NoteUpdated("note-1"),
            DomainEvent.NoteDeleted("note-1"),
            DomainEvent.MeditationCompleted,
        )
        events.mapNotNull(AnalyticsEventMapper::from).forEach {
            assertTrue(it.name.length <= 40)
            assertTrue(it.params.size <= 50)
        }
    }
}
