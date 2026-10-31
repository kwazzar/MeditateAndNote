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
        DomainEvent.MeditationCompleted -> AnalyticsEvent("meditation_completed")
    }
}
