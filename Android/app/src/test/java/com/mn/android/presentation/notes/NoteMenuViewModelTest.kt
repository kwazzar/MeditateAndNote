package com.mn.android.presentation.notes

import com.mn.android.domain.note.NoteDraft
import com.mn.android.note.FakeNoteRepository
import com.mn.android.presentation.notes.viewmodel.NoteMenuViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * The notes list and its search.
 *
 * The search looks into the whole note, not into the card's preview - the
 * iOS list searches the full text too.
 */
class NoteMenuViewModelTest {

    @Before
    fun setup() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun everyNoteIsInTheList() = runTest {
        val vm = viewModelWithOneNote()

        assertEquals(1, vm.state.value.notes.size)
    }

    @Test
    fun theSearchLooksIntoTheWholeNote() = runTest {
        val vm = viewModelWithOneNote()

        vm.updateQuery("deep")
        advanceUntilIdle()

        assertEquals("the word sits past the card's preview", 1, vm.state.value.notes.size)
    }

    @Test
    fun theSearchLooksIntoTheTitle() = runTest {
        val vm = viewModelWithOneNote()

        vm.updateQuery("morning")
        advanceUntilIdle()

        assertEquals(1, vm.state.value.notes.size)
    }

    @Test
    fun aQueryThatMatchesNothingEmptiesTheList() = runTest {
        val vm = viewModelWithOneNote()

        vm.updateQuery("absent")
        advanceUntilIdle()

        assertEquals(0, vm.state.value.notes.size)
    }

    private suspend fun kotlinx.coroutines.test.TestScope.viewModelWithOneNote(): NoteMenuViewModel {
        val repo = FakeNoteRepository()
        val id = repo.newId()
        // The word sits past the 120 characters the card used to show, so a
        // search that only looks at the preview would miss it.
        val body = "a".repeat(200) + " the deep word"
        repo.save(id, NoteDraft("Morning", body))
        val vm = NoteMenuViewModel(repo)
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { vm.state.collect {} }
        advanceUntilIdle()
        return vm
    }
}
