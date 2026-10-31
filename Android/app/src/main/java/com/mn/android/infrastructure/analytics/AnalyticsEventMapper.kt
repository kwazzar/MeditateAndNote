package com.mn.android.infrastructure.analytics

import com.mn.android.domain.events.DomainEvent

/**
 * Maps the Android domain-event mirror to Firebase Analytics.
 *
 * Privacy boundary: no note content, note IDs, book IDs, prompts or provider
 * messages leave the device.
 */
object AnalyticsEventMapper {
    fun from(event: DomainEvent): AnalyticsEvent? = when (event) {
        is DomainEvent.NoteCreated -> AnalyticsEvent("note_created")
        is DomainEvent.NoteUpdated -> AnalyticsEvent("note_updated")
        is DomainEvent.NoteDeleted -> AnalyticsEvent("note_deleted")
        is DomainEvent.MeditationCompleted -> AnalyticsEvent(
            "meditation_completed",
            mapOf(
                "meditation_id" to event.meditationId,
                "duration_seconds" to event.durationSeconds,
            ),
        )
        DomainEvent.AiDraftGenerated -> AnalyticsEvent("ai_draft_generated")
        is DomainEvent.AiDraftMetric -> metricEvent(event)
    }

    private fun metricEvent(metric: DomainEvent.AiDraftMetric): AnalyticsEvent = when (metric) {
        is DomainEvent.AiDraftMetric.GenerationStarted -> AnalyticsEvent(
            "ai_draft_metric",
            mapOf(
                "metric_type" to "generation_started",
                "warm_cold" to metric.warmCold,
            ),
        )
        is DomainEvent.AiDraftMetric.GenerationCompleted -> AnalyticsEvent(
            "ai_draft_metric",
            mapOf(
                "metric_type" to "generation_completed",
                "latency_ms" to metric.latencyMs,
                "suggestion_count" to metric.suggestionCount,
            ),
        )
        is DomainEvent.AiDraftMetric.GenerationFailed -> AnalyticsEvent(
            "ai_draft_metric",
            mapOf(
                "metric_type" to "generation_failed",
                "error_kind" to metric.errorKind,
            ),
        )
        is DomainEvent.AiDraftMetric.SuggestionInserted -> AnalyticsEvent(
            "ai_draft_metric",
            mapOf(
                "metric_type" to "suggestion_inserted",
                "index" to metric.index,
            ),
        )
        is DomainEvent.AiDraftMetric.SuggestionRejected -> AnalyticsEvent(
            "ai_draft_metric",
            mapOf(
                "metric_type" to "suggestion_rejected",
                "index" to metric.index,
            ),
        )
    }
}
