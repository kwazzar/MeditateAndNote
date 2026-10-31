package com.mn.android.domain.events

/**
 * Android transport mirror of the Core `DomainEvent` cases this port emits.
 *
 * The domain rules stay in Swift: `NoteEditorSource`/`SessionRecorder` decide
 * what a mutation means (new note vs. update, session saved) and this bus only
 * carries the fact to the screens. It is deliberately not the 8-case Core enum
 * — the cases no Android publisher or consumer exists for are not mirrored, so
 * adding one to Core does not silently promise Android support.
 */
sealed interface DomainEvent {
    data class NoteCreated(val noteId: String) : DomainEvent
    data class NoteUpdated(val noteId: String) : DomainEvent
    data class NoteDeleted(val noteId: String) : DomainEvent

    /** Parameters mirror the iOS analytics payload: built-in id + duration. */
    data class MeditationCompleted(
        val meditationId: String,
        val durationSeconds: Int,
    ) : DomainEvent

    /** One successful draft generation - published once, not per suggestion. */
    data object AiDraftGenerated : DomainEvent

    /**
     * Mirror of Core `AIDraftMetric`: counts, latency and a typed kind - never
     * prompt text or the model's answer. Published next to the Room telemetry
     * row, which stays the on-device debug source.
     */
    sealed interface AiDraftMetric : DomainEvent {
        data class GenerationStarted(val warmCold: Boolean) : AiDraftMetric
        data class GenerationCompleted(val latencyMs: Int, val suggestionCount: Int) : AiDraftMetric
        data class GenerationFailed(val errorKind: String) : AiDraftMetric
        data class SuggestionInserted(val index: Int) : AiDraftMetric
        data class SuggestionRejected(val index: Int) : AiDraftMetric
    }
}
