package com.mn.android.presentation.notes.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mn.android.domain.note.NoteListItem
import com.mn.android.domain.note.NoteRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn

/**
 * The notes list.
 *
 * The list comes from the repository, which re-reads it whenever a note
 * changes — the Android counterpart of the iOS event subscription. The search
 * is a local case-insensitive contains over title and content, the same rule
 * the iOS `SearchState` applies.
 */
class NoteMenuViewModel(
    notes: NoteRepository,
) : ViewModel() {

    private val query = MutableStateFlow("")

    val state: StateFlow<NoteMenuState> =
        combine(notes.observe(), query) { all, text ->
            NoteMenuState(notes = all.filter { it.matches(text) }, query = text)
        }.stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS),
            initialValue = NoteMenuState(),
        )

    fun updateQuery(text: String) {
        query.value = text
    }

    private fun NoteListItem.matches(text: String): Boolean {
        val needle = text.trim()
        if (needle.isEmpty()) return true
        return title.contains(needle, ignoreCase = true) ||
            content.contains(needle, ignoreCase = true)
    }

    private companion object {
        const val STOP_TIMEOUT_MS = 5_000L
    }
}

data class NoteMenuState(
    val notes: List<NoteListItem> = emptyList(),
    val query: String = "",
)
