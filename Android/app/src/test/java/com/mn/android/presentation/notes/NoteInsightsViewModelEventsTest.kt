package com.mn.android.presentation.notes

import com.mn.android.data.NoteInsightsSource
import com.mn.android.domain.events.DomainEvent
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
        var loads = 0
        viewModel(loads = { loads++ })

        events.emit(DomainEvent.NoteCreated("note-1"))

        assertEquals(1, loads)
    }

    @Test
    fun meditationEventLeavesTheInsightsAlone() = runTest {
        var loads = 0
        viewModel(loads = { loads++ })

        events.emit(DomainEvent.MeditationCompleted)

        assertEquals(0, loads)
    }

    private fun viewModel(loads: () -> Unit) = NoteInsightsViewModel(
        loadStored = {
            loads()
            listOf(
                NoteInsightsSource.Insight(
                    id = "stored",
                    summary = "stored",
                    tags = listOf("calm"),
                    themes = listOf(NoteInsightsSource.Theme("calm", 1.0)),
                )
            )
        },
        loadHeuristic = { emptyList() },
        runAnalysis = { NoteInsightsSource.Analysis(emptyList(), "") },
        ioDispatcher = UnconfinedTestDispatcher(),
        events = events,
    )
}
