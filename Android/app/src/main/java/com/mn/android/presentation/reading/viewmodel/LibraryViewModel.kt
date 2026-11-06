package com.mn.android.presentation.reading.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mn.android.domain.book.BookId
import com.mn.android.domain.book.BookRepository
import com.mn.android.domain.book.BookSummary
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.InputStream

/**
 * The library the books tab shows.
 *
 * The screen only decides what is on it (the grid, the picker, the dialogs);
 * the list, the covers and the import/delete live here.
 */
class LibraryViewModel(
    private val repository: BookRepository,
) : ViewModel() {

    data class UiState(
        val books: List<BookSummary> = emptyList(),
        /** The cover bytes per book — the screen decodes them into bitmaps. */
        val covers: Map<BookId, ByteArray> = emptyMap(),
        val isLoading: Boolean = false,
        val importFailed: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState())

    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        load()
    }

    /** Reads the library and the covers. */
    fun load() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }
            val summaries = runCatching { repository.readLibrary() }.getOrDefault(emptyList())
            val covers = summaries.mapNotNull { summary ->
                val bytes = runCatching { repository.cover(summary.id) }.getOrNull()?.getOrNull()
                if (bytes != null) summary.id to bytes else null
            }.toMap()
            _state.update { it.copy(books = summaries, covers = covers, isLoading = false) }
        }
    }

    /**
     * Imports the picked document.
     *
     * The stream is the caller's (the picker's) — the adapter closes it.
     */
    fun import(name: String, content: InputStream) {
        viewModelScope.launch {
            val imported = repository.importDocument(name, content)
            if (imported.isSuccess) {
                load()
            } else {
                _state.update { it.copy(importFailed = true) }
            }
        }
    }

    /** Removes the book and everything that belongs to it. */
    fun delete(id: BookId) {
        viewModelScope.launch {
            repository.delete(id)
            load()
        }
    }

    /** The picked file could not be read at all. */
    fun reportImportFailure() {
        _state.update { it.copy(importFailed = true) }
    }

    fun dismissImportError() {
        _state.update { it.copy(importFailed = false) }
    }
}
