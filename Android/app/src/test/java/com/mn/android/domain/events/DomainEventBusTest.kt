package com.mn.android.domain.events

import kotlinx.coroutines.async
import kotlinx.coroutines.flow.take
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The bus is the only transport between the mutation points and the screens:
 * a dropped or duplicated event leaves a screen stale, so fan-out and order
 * are the whole contract.
 */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class DomainEventBusTest {

    @Test
    fun everySubscriberReceivesTheEvent() = runTest {
        val first = async(UnconfinedTestDispatcher(testScheduler)) {
            DomainEventBus.events.take(1).toList()
        }
        val second = async(UnconfinedTestDispatcher(testScheduler)) {
            DomainEventBus.events.take(1).toList()
        }

        DomainEventBus.publish(DomainEvent.NoteDeleted("note-1"))

        assertEquals(listOf(DomainEvent.NoteDeleted("note-1")), first.await())
        assertEquals(listOf(DomainEvent.NoteDeleted("note-1")), second.await())
    }

    @Test
    fun eventsArriveInPublishOrder() = runTest {
        val received = async(UnconfinedTestDispatcher(testScheduler)) {
            DomainEventBus.events.take(3).toList()
        }

        DomainEventBus.publish(DomainEvent.NoteCreated("a"))
        DomainEventBus.publish(DomainEvent.NoteUpdated("a"))
        DomainEventBus.publish(DomainEvent.MeditationCompleted("breathing-4-7-8", 305))

        assertEquals(
            listOf(
                DomainEvent.NoteCreated("a"),
                DomainEvent.NoteUpdated("a"),
                DomainEvent.MeditationCompleted("breathing-4-7-8", 305),
            ),
            received.await(),
        )
    }
}
