package com.mn.android.domain.events

import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * Publisher contract for [DomainEvent]s. The Android counterpart of the iOS
 * `DomainEventPublisher` protocol: lets a manager depend on the abstraction
 * instead of the concrete bus.
 */
interface DomainEventPublisher {
    /** Safe from any thread. */
    fun publish(event: DomainEvent)
}

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
 *
 * Entitlement is the exception: it is state, not invalidation. A premium
 * change that nobody was around for leaves the app unlocked (or locked)
 * until the next refresh, so the last one is kept and replayed to whoever
 * subscribes next.
 */
object DomainEventBus : DomainEventPublisher {

    private val _events = MutableSharedFlow<DomainEvent>(
        extraBufferCapacity = 64,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )

    val events: SharedFlow<DomainEvent> = _events.asSharedFlow()

    /**
     * The last entitlement change, replayed to a late subscriber.
     *
     * Only the latest one is kept: entitlement is a state, not a history.
     */
    private val _entitlementChanges = MutableSharedFlow<DomainEvent.SubscriptionChanged>(
        replay = 1,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )

    val entitlementChanges: SharedFlow<DomainEvent.SubscriptionChanged> =
        _entitlementChanges.asSharedFlow()

    /** Safe from any thread; publishers today are main-thread UI callbacks. */
    override fun publish(event: DomainEvent) {
        _events.tryEmit(event)
        if (event is DomainEvent.SubscriptionChanged) {
            _entitlementChanges.tryEmit(event)
        }
    }
}
