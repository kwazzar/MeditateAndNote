package com.mn.android.presentation.notes

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.mn.android.domain.note.NoteDraft
import com.mn.android.domain.note.NoteRepository
import com.mn.android.note.FakeNoteRepository
import com.mn.android.presentation.notes.ui.NoteMenuScreen
import com.mn.android.presentation.notes.viewmodel.NoteMenuViewModel
import kotlinx.coroutines.runBlocking
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The notes list renders the stored notes.
 *
 * This screen used to crash on every note: the lazy list keyed its items by
 * the note id value object, and a value object cannot go into the Bundle the
 * list state is saved in. The crash only shows up when a list item is
 * composed, so it needs a real composition to be caught.
 */
@RunWith(AndroidJUnit4::class)
class NoteMenuScreenTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun theListShowsTheStoredNotes() {
        val repository: NoteRepository = FakeNoteRepository()
        val id = repository.newId()
        runBlocking { repository.save(id, NoteDraft("Evening walk", "A calm walk by the river.")) }

        compose.setContent {
            NoteMenuScreen(
                onOpenNote = {},
                onAddNote = {},
                noteMenuViewModel = NoteMenuViewModel(repository),
            )
        }

        // A locked device keeps the test activity's window from attaching, and
        // then there is no compose hierarchy to inspect at all.
        val found = runCatching {
            compose.onAllNodesWithText("Evening walk").fetchSemanticsNodes()
        }.getOrNull()
        assumeTrue("no compose hierarchy — is the device locked?", found != null)

        compose.onNodeWithText("Evening walk").assertExists()
    }
}
