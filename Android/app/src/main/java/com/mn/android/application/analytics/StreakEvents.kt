package com.mn.android.application.analytics

import com.mn.android.data.StreakHeaderSource
import com.mn.android.domain.events.DomainEvent
import com.mn.android.domain.events.DomainEventBus

/**
 * Publishes the streak events the iOS `StreakTracker` publishes.
 *
 * Android's streak lives in the Swift domain (`KotlinStreakActivityStore`
 * recounts it when a note or a session is written) and Kotlin only reads it
 * back through `StreakHeaderSource`. The last observed value is the baseline:
 * a longer streak extends, a shorter one breaks - the same comparison iOS
 * makes in `StreakTracker.apply`.
 *
 * The first read only establishes the baseline, like the iOS tracker's
 * `checkStreakBreak` in `init`: a streak that expired while the app was
 * closed is reported when the next activity is written, not at launch.
 */
object StreakEvents {

    private var lastObserved: Int? = null

    @Synchronized
    fun sync() {
        val current = runCatching { StreakHeaderSource.readHeader().currentStreak }.getOrNull() ?: return
        val previous = lastObserved
        lastObserved = current
        if (previous == null) return
        when {
            current > previous -> DomainEventBus.publish(DomainEvent.StreakExtended(current))
            current < previous && previous > 0 -> DomainEventBus.publish(DomainEvent.StreakBroken(previous))
        }
    }
}
