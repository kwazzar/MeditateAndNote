package com.mn.android.presentation.notes

import com.mn.android.data.NoteInsightsSource
import com.mn.android.presentation.notes.viewmodel.NoteInsightsViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * The state holder the notes tab draws: the stored insights win over the
 * heuristic ones, a failed pass keeps the old insights and reports the
 * error.
 */
class NoteInsightsViewModelTest {

    @Before
    fun setup() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun load_showsTheStoredInsights() {
        val stored = insight("stored")
        val vm = viewModel(
            loadStored = { listOf(stored) },
            loadHeuristic = { listOf(insight("heuristic")) },
        )

        vm.load()

        assertEquals(listOf(stored), vm.state.value.insights)
        assertTrue(vm.state.value.hasLoaded)
        assertNull(vm.state.value.error)
    }

    @Test
    fun load_fallsBackToTheHeuristic_whenNothingIsStored() {
        val heuristic = insight("heuristic")
        val vm = viewModel(
            loadStored = { emptyList() },
            loadHeuristic = { listOf(heuristic) },
        )

        vm.load()

        assertEquals(listOf(heuristic), vm.state.value.insights)
    }

    @Test
    fun refresh_showsWhatThePassFound() {
        val analyzed = insight("analyzed")
        val vm = viewModel(
            loadStored = { listOf(insight("stored")) },
            runAnalysis = { NoteInsightsSource.Analysis(listOf(analyzed), "llm") },
        )

        vm.refresh()

        assertEquals(listOf(analyzed), vm.state.value.insights)
        assertNull(vm.state.value.error)
    }

    @Test
    fun refresh_keepsTheOldInsights_whenThePassFails() {
        val stored = insight("stored")
        val vm = viewModel(
            loadStored = { listOf(stored) },
            runAnalysis = { NoteInsightsSource.Analysis(emptyList(), "", "providerUnavailable") },
        )
        vm.load()

        vm.refresh()

        assertEquals(listOf(stored), vm.state.value.insights)
        assertEquals("providerUnavailable", vm.state.value.error)
    }

    private fun viewModel(
        loadStored: suspend () -> List<NoteInsightsSource.Insight>,
        loadHeuristic: suspend () -> List<NoteInsightsSource.Insight> = { emptyList() },
        runAnalysis: suspend () -> NoteInsightsSource.Analysis = {
            NoteInsightsSource.Analysis(emptyList(), "")
        },
    ) = NoteInsightsViewModel(
        loadStored = loadStored,
        loadHeuristic = loadHeuristic,
        runAnalysis = runAnalysis,
        ioDispatcher = UnconfinedTestDispatcher(),
    )

    private fun insight(summary: String) = NoteInsightsSource.Insight(
        id = summary,
        summary = summary,
        tags = listOf("calm"),
        themes = listOf(NoteInsightsSource.Theme("calm", 1.0)),
    )
}
