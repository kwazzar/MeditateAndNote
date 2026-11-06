package com.mn.android.presentation.notes

import com.mn.android.domain.events.DomainEvent
import com.mn.android.insights.FakeNoteInsightsRepository
import com.mn.android.presentation.notes.viewmodel.NoteInsightsViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * The insights are stale the moment a note changes, so the ViewModel listens
 * for the note events and reads them again — the iOS behaviour, where
 * `.noteCreated`/`.noteUpdated`/`.noteDeleted` reach the insights section.
 */
class NoteInsightsViewModelEventsTest {

    private val events = MutableSharedFlow<DomainEvent>(extraBufferCapacity = 8)

    @Before
    fun setup() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun noteEventReloadsTheInsights() = runTest {
        val repository = FakeNoteInsightsRepository()

        viewModel(repository)

        events.emit(DomainEvent.NoteCreated("note-1"))

        assertEquals(1, repository.storedCalls)
    }

    @Test
    fun meditationEventLeavesTheInsightsAlone() = runTest {
        val repository = FakeNoteInsightsRepository()

        viewModel(repository)

        events.emit(DomainEvent.MeditationCompleted("breathing-4-7-8", 305))

        assertEquals(0, repository.storedCalls)
    }

    private fun viewModel(repository: FakeNoteInsightsRepository) = NoteInsightsViewModel(
        repository = repository,
        ioDispatcher = UnconfinedTestDispatcher(),
        events = events,
    )
}
