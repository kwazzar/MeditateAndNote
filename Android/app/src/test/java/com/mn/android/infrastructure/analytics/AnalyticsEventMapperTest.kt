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
    fun `ai draft generated maps without payload`() {
        val event = AnalyticsEventMapper.from(DomainEvent.AiDraftGenerated)
        assertEquals("ai_draft_generated", event?.name)
        assertTrue(event!!.params.isEmpty())
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
