package com.mn.android.domain.events

import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * In-process fan-out for [DomainEvent]s. The Android counterpart of what
 * `DomainEventBus` + `EventLoopCoordinator` do on iOS: one publisher per
 * mutation, every live screen subscriber sees the same events in publish
 * order.
 *
 * No replay on purpose: a subscriber that was not active (the screen was not
 * composed) misses the event, but that screen re-reads its source on first
 * composition anyway — a replayed event would only cause a redundant reload.
 * The buffer is small and lossy under sustained bursts, which is fine for
 * invalidation-style consumers: they reload from the store, so a dropped
 * older reload collapses into the newest one.
 */
object DomainEventBus {

    private val _events = MutableSharedFlow<DomainEvent>(
        extraBufferCapacity = 64,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )

    val events: SharedFlow<DomainEvent> = _events.asSharedFlow()

    /** Safe from any thread; publishers today are main-thread UI callbacks. */
    fun publish(event: DomainEvent) {
        _events.tryEmit(event)
    }
}
