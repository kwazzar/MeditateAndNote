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
    data object MeditationCompleted : DomainEvent
}
