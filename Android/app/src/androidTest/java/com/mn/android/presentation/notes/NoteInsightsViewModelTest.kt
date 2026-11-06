package com.mn.android.presentation.notes

import com.mn.android.domain.insights.NoteInsight
import com.mn.android.domain.insights.NoteInsightTheme
import com.mn.android.domain.insights.NoteInsightsAnalysis
import com.mn.android.insights.FakeNoteInsightsRepository
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
        val repository = FakeNoteInsightsRepository().apply { insights = listOf(stored) }
        val vm = viewModel(repository)

        vm.load()

        assertEquals(listOf(stored), vm.state.value.insights)
        assertTrue(vm.state.value.hasLoaded)
        assertNull(vm.state.value.error)
    }

    @Test
    fun load_fallsBackToTheHeuristic_whenNothingIsStored() {
        val heuristic = insight("heuristic")
        val repository = FakeNoteInsightsRepository().apply { insights = listOf(heuristic) }
        val vm = viewModel(repository)

        vm.load()

        assertEquals(listOf(heuristic), vm.state.value.insights)
    }

    @Test
    fun refresh_showsWhatThePassFound() {
        val analyzed = insight("analyzed")
        val repository = FakeNoteInsightsRepository().apply {
            insights = listOf(insight("stored"))
            analysis = NoteInsightsAnalysis(listOf(analyzed), "llm")
        }
        val vm = viewModel(repository)

        vm.refresh()

        assertEquals(listOf(analyzed), vm.state.value.insights)
        assertNull(vm.state.value.error)
    }

    @Test
    fun refresh_keepsTheOldInsights_whenThePassFails() {
        val stored = insight("stored")
        val repository = FakeNoteInsightsRepository().apply {
            insights = listOf(stored)
            analysis = NoteInsightsAnalysis(emptyList(), "", "providerUnavailable")
        }
        val vm = viewModel(repository)
        vm.load()

        vm.refresh()

        assertEquals(listOf(stored), vm.state.value.insights)
        assertEquals("providerUnavailable", vm.state.value.error)
    }

    @Test
    fun topThemes_ranksTheMostFrequentLabelsFirst() {
        val repository = FakeNoteInsightsRepository().apply {
            insights = listOf(
                insight("a").copy(
                    themes = listOf(NoteInsightTheme("calm", 1.0), NoteInsightTheme("sleep", 0.5)),
                ),
                insight("b").copy(themes = listOf(NoteInsightTheme("calm", 0.8))),
            )
        }
        val vm = viewModel(repository)

        vm.load()

        assertEquals(listOf("calm", "sleep"), vm.topThemes)
    }

    private fun viewModel(repository: FakeNoteInsightsRepository) = NoteInsightsViewModel(
        repository = repository,
        ioDispatcher = UnconfinedTestDispatcher(),
    )

    private fun insight(summary: String) = NoteInsight(
        id = summary,
        summary = summary,
        tags = listOf("calm"),
        themes = listOf(NoteInsightTheme("calm", 1.0)),
    )
}
