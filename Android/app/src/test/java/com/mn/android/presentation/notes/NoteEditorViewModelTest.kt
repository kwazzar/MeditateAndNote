package com.mn.android.presentation.notes

import com.mn.android.aidraft.FakeAIDraftRepository
import com.mn.android.aidraft.FakeAIDraftSettings
import com.mn.android.aidraft.RecordingAIDraftMetricRecorder
import com.mn.android.note.FakeNoteRepository
import com.mn.android.presentation.notes.viewmodel.NoteEditorViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.TestCoroutineScheduler
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

/**
 * The editor's rules: the blank note is never stored, the autosave waits for
 * the pause in typing, and the back button saves what is on screen.
 */
class NoteEditorViewModelTest {

    private val scheduler = TestCoroutineScheduler()

    @Before
    fun setup() {
        Dispatchers.setMain(UnconfinedTestDispatcher(scheduler))
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun theAutosaveStoresTheNoteAfterThePause() = runTest(scheduler) {
        val notes = FakeNoteRepository()
        val vm = viewModel(notes)

        vm.onBodyChange("a calm morning")
        advanceUntilIdle()

        val stored = notes.get(vm.state.value.id).getOrNull()
        assertNotNull("the note has to be stored", stored)
        assertEquals("a calm morning", stored!!.content)
    }

    @Test
    fun aBlankNoteIsNeverStored() = runTest(scheduler) {
        val notes = FakeNoteRepository()
        val vm = viewModel(notes)

        vm.onTitleChange("   ")
        advanceUntilIdle()

        assertNull(notes.get(vm.state.value.id).getOrNull())
    }

    @Test
    fun theBackButtonStoresTheNote() = runTest(scheduler) {
        val notes = FakeNoteRepository()
        val vm = viewModel(notes)

        vm.onBodyChange("written on the way out")
        vm.save()
        advanceUntilIdle()

        assertNotNull(notes.get(vm.state.value.id).getOrNull())
    }

    @Test
    fun theDeleteTakesTheNoteAway() = runTest(scheduler) {
        val notes = FakeNoteRepository()
        val vm = viewModel(notes)
        vm.onBodyChange("to be deleted")
        vm.save()
        advanceUntilIdle()

        vm.delete()
        advanceUntilIdle()

        assertNull(notes.get(vm.state.value.id).getOrNull())
    }

    private fun kotlinx.coroutines.test.TestScope.viewModel(
        notes: FakeNoteRepository,
    ): NoteEditorViewModel = NoteEditorViewModel(
        noteId = notes.newId(),
        isNew = true,
        notes = notes,
        drafts = FakeAIDraftRepository(),
        draftSettings = FakeAIDraftSettings(),
        metricRecorder = RecordingAIDraftMetricRecorder(),
        backgroundScope = this,
        autosaveDelayMs = 100,
    )
}
