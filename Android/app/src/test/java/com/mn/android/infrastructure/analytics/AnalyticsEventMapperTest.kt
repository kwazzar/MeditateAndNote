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
    fun `meditation completion carries only built-in id and duration`() {
        val event = AnalyticsEventMapper.from(
            DomainEvent.MeditationCompleted("breathing-4-7-8", 305),
        )
        assertEquals("meditation_completed", event?.name)
        assertEquals(mapOf("meditation_id" to "breathing-4-7-8", "duration_seconds" to 305), event!!.params)
    }

    @Test
    fun `meditation started carries only built-in id`() {
        val event = AnalyticsEventMapper.from(DomainEvent.MeditationStarted("breathing-4-7-8"))
        assertEquals("meditation_started", event?.name)
        assertEquals(mapOf("meditation_id" to "breathing-4-7-8"), event!!.params)
    }

    @Test
    fun `ai draft generated maps without payload`() {
        val event = AnalyticsEventMapper.from(DomainEvent.AiDraftGenerated)
        assertEquals("ai_draft_generated", event?.name)
        assertTrue(event!!.params.isEmpty())
    }

    @Test
    fun `subscription changed maps is_premium`() {
        val event = AnalyticsEventMapper.from(DomainEvent.SubscriptionChanged(true))
        assertEquals("subscription_changed", event?.name)
        assertEquals(mapOf("is_premium" to true), event!!.params)

        val eventFree = AnalyticsEventMapper.from(DomainEvent.SubscriptionChanged(false))
        assertEquals("subscription_changed", eventFree?.name)
        assertEquals(mapOf("is_premium" to false), eventFree!!.params)
    }

    @Test
    fun `book imported maps format`() {
        val event = AnalyticsEventMapper.from(DomainEvent.BookImported("epub"))
        assertEquals("book_imported", event?.name)
        assertEquals(mapOf("format" to "epub"), event!!.params)
    }

    @Test
    fun `reader opened maps without id`() {
        val event = AnalyticsEventMapper.from(DomainEvent.ReaderOpened("book-123"))
        assertEquals("reader_opened", event?.name)
        assertTrue(event!!.params.isEmpty())
    }

    @Test
    fun `bookmark created maps type`() {
        val pageEvent = AnalyticsEventMapper.from(DomainEvent.BookmarkCreated("page"))
        assertEquals("bookmark_created", pageEvent?.name)
        assertEquals(mapOf("type" to "page"), pageEvent!!.params)

        val highlightEvent = AnalyticsEventMapper.from(DomainEvent.BookmarkCreated("highlight"))
        assertEquals("bookmark_created", highlightEvent?.name)
        assertEquals(mapOf("type" to "highlight"), highlightEvent!!.params)
    }

    @Test
    fun `streak extended maps days`() {
        val event = AnalyticsEventMapper.from(DomainEvent.StreakExtended(7))
        assertEquals("streak_extended", event?.name)
        assertEquals(mapOf("days" to 7), event!!.params)
    }

    @Test
    fun `streak broken maps previous days`() {
        val event = AnalyticsEventMapper.from(DomainEvent.StreakBroken(14))
        assertEquals("streak_broken", event?.name)
        assertEquals(mapOf("previous_days" to 14), event!!.params)
    }

    @Test
    fun `ai draft metrics mirror the ios schema`() {
        val cases = listOf(
            DomainEvent.AiDraftMetric.GenerationStarted(warmCold = false) to mapOf(
                "metric_type" to "generation_started",
                "warm_cold" to false,
            ),
            DomainEvent.AiDraftMetric.GenerationCompleted(latencyMs = 721, suggestionCount = 2) to mapOf(
                "metric_type" to "generation_completed",
                "latency_ms" to 721,
                "suggestion_count" to 2,
            ),
            DomainEvent.AiDraftMetric.GenerationFailed(errorKind = "providerUnavailable") to mapOf(
                "metric_type" to "generation_failed",
                "error_kind" to "providerUnavailable",
            ),
            DomainEvent.AiDraftMetric.SuggestionInserted(index = 1) to mapOf(
                "metric_type" to "suggestion_inserted",
                "index" to 1,
            ),
            DomainEvent.AiDraftMetric.SuggestionRejected(index = 0) to mapOf(
                "metric_type" to "suggestion_rejected",
                "index" to 0,
            ),
        )
        cases.forEach { (domain, params) ->
            val event = AnalyticsEventMapper.from(domain)
            assertEquals("ai_draft_metric", event?.name)
            assertEquals(params, event!!.params)
        }
    }

    @Test
    fun `event names stay within firebase limit`() {
        val events = listOf(
            DomainEvent.NoteCreated("note-1"),
            DomainEvent.NoteUpdated("note-1"),
            DomainEvent.NoteDeleted("note-1"),
            DomainEvent.MeditationCompleted("breathing-4-7-8", 305),
            DomainEvent.MeditationStarted("breathing-4-7-8"),
            DomainEvent.SubscriptionChanged(true),
            DomainEvent.BookImported("epub"),
            DomainEvent.ReaderOpened("book-123"),
            DomainEvent.BookmarkCreated("page"),
            DomainEvent.StreakExtended(7),
            DomainEvent.StreakBroken(14),
            DomainEvent.AiDraftGenerated,
            DomainEvent.AiDraftMetric.GenerationStarted(false),
            DomainEvent.AiDraftMetric.GenerationCompleted(721, 2),
            DomainEvent.AiDraftMetric.GenerationFailed("providerUnavailable"),
            DomainEvent.AiDraftMetric.SuggestionInserted(1),
            DomainEvent.AiDraftMetric.SuggestionRejected(0),
        )
        events.mapNotNull(AnalyticsEventMapper::from).forEach {
            assertTrue(it.name.length <= 40)
            assertTrue(it.params.size <= 50)
        }
    }
}
