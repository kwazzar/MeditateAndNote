package com.mn.android.presentation.reading.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mn.android.domain.book.BookId
import com.mn.android.domain.book.BookRepository
import com.mn.android.domain.book.Bookmark
import com.mn.android.domain.book.BookmarkId
import com.mn.android.domain.book.BookmarkRepository
import com.mn.android.domain.book.Chapter
import com.mn.android.domain.book.ReadingPosition
import com.mn.android.domain.book.ReaderLayout
import com.mn.android.domain.events.DomainEvent
import com.mn.android.domain.events.DomainEventBus
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * The reading session: the book, the page being read, the marks.
 *
 * The layout (the font size, the page box) is the screen's — it is measured
 * from the window — and it is handed over as a [ReaderLayout]. The engine
 * does the pagination; this holds the state the reader draws and the writes
 * the session needs (the position, the marks).
 */
class ReaderViewModel(
    private val bookId: BookId,
    private val books: BookRepository,
    private val bookmarks: BookmarkRepository,
    /**
     * The scope for the write that must not be cancelled by the reader
     * closing: the position the reader was at.
     */
    private val backgroundScope: CoroutineScope,
) : ViewModel() {

    /** The lines of one page, with the position of every line. */
    data class PageLines(
        val lines: List<String>,
        val positions: List<ReadingPosition>,
    )

    data class UiState(
        val title: String = "",
        val pageCount: Int = 0,
        val page: Int = 0,
        val lines: List<String> = emptyList(),
        val linePositions: List<ReadingPosition> = emptyList(),
        val progress: Float = 0f,
        val loadFailed: Boolean = false,
        val chapters: List<Chapter> = emptyList(),
        val marks: List<Bookmark> = emptyList(),
        /** The pages that were loaded already; the scroll mode renders them lazily. */
        val pages: Map<Int, PageLines> = emptyMap(),
    )

    private val _state = MutableStateFlow(UiState())

    val state: StateFlow<UiState> = _state.asStateFlow()

    /**
     * Opens the book and lays it out for [layout].
     *
     * Opening paginates the whole text, so the first page can take a moment;
     * the screen shows a loading state until the page count is known.
     */
    fun open(layout: ReaderLayout) {
        viewModelScope.launch {
            runCatching {
                val opened = books.open(bookId, layout).getOrThrow()
                val page = books.page(opened.page).getOrThrow()
                _state.update {
                    it.copy(
                        title = opened.title,
                        page = opened.page,
                        pageCount = opened.pageCount,
                        lines = page.lines,
                        linePositions = page.positions,
                        progress = page.progress.toFloat(),
                        pages = it.pages + (opened.page to PageLines(page.lines, page.positions)),
                        loadFailed = false,
                    )
                }
                DomainEventBus.publish(DomainEvent.ReaderOpened(bookId.value))
                _state.update {
                    it.copy(chapters = bookmarks.readChapters(bookId), marks = bookmarks.readMarks(bookId))
                }
            }.onFailure {
                // The screen shows the failure state; the ViewModel must not
                // log through android.util.Log - the unit tests cannot run it.
                _state.update { it.copy(loadFailed = true) }
            }
        }
    }

    /**
     * Turns to [index] and remembers the position.
     *
     * [scrollMode] is the reader's continuous-column mode: there the page is
     * on screen already, so only the page number and the position change.
     */
    fun showPage(index: Int, scrollMode: Boolean) {
        val pageCount = _state.value.pageCount
        val clamped = index.coerceIn(0, (pageCount - 1).coerceAtLeast(0))
        if (scrollMode) {
            _state.update {
                it.copy(
                    page = clamped,
                    progress = if (pageCount > 1) clamped.toFloat() / (pageCount - 1) else 0f,
                )
            }
            viewModelScope.launch { books.savePosition(bookId, clamped) }
            return
        }
        viewModelScope.launch {
            val readerPage = books.page(clamped).getOrNull()
            if (readerPage != null) {
                _state.update {
                    it.copy(
                        page = clamped,
                        lines = readerPage.lines,
                        linePositions = readerPage.positions,
                        progress = readerPage.progress.toFloat(),
                        pages = it.pages + (clamped to PageLines(readerPage.lines, readerPage.positions)),
                    )
                }
            }
            books.savePosition(bookId, clamped)
            // The neighbour pages are what the slide animation renders next;
            // loading them now keeps the turn instant.
            for (neighbour in intArrayOf(clamped - 1, clamped + 1)) {
                if (neighbour in 0 until pageCount && _state.value.pages[neighbour] == null) {
                    books.page(neighbour).getOrNull()?.let {
                        _state.update { state ->
                            state.copy(pages = state.pages + (neighbour to PageLines(it.lines, it.positions)))
                        }
                    }
                }
            }
        }
    }

    /** Loads a page into the cache — the scroll mode asks for them lazily. */
    fun loadPage(index: Int) {
        if (_state.value.pages[index] != null) return
        viewModelScope.launch {
            books.page(index).getOrNull()?.let {
                _state.update { state ->
                    state.copy(pages = state.pages + (index to PageLines(it.lines, it.positions)))
                }
            }
        }
    }

    /** The lines of a page from the cache, or an empty list. */
    fun pageLines(index: Int): PageLines? = _state.value.pages[index]

    /** The scroll mode moved: the page on screen is the one being read. */
    fun onVisiblePage(index: Int) {
        val pageCount = _state.value.pageCount
        _state.update {
            it.copy(
                page = index,
                progress = if (pageCount > 1) index.toFloat() / (pageCount - 1) else 0f,
            )
        }
    }

    /**
     * Lays the book out again — after a font size change.
     *
     * The cache holds lines from the previous layout: every entry would wrap
     * at the old width and drift the scroll list, so it goes.
     */
    fun repaginate(layout: ReaderLayout, scrollMode: Boolean) {
        viewModelScope.launch {
            val result = books.repaginate(bookId, layout).getOrNull() ?: return@launch
            val opened = books.open(bookId, layout).getOrNull() ?: return@launch
            _state.update { it.copy(pageCount = result.pageCount, pages = emptyMap()) }
            showPage(opened.page, scrollMode)
        }
    }

    /** Reads the table of contents again — the sheets open it fresh. */
    fun refreshChapters() {
        viewModelScope.launch {
            _state.update { it.copy(chapters = bookmarks.readChapters(bookId)) }
        }
    }

    /** Reads the marks again. */
    fun refreshMarks() {
        viewModelScope.launch {
            _state.update { it.copy(marks = bookmarks.readMarks(bookId)) }
        }
    }

    /** The page a mark points at, in the current layout. */
    suspend fun pageFor(mark: Bookmark): Int = bookmarks.pageForPosition(mark.position)

    /** Removes a mark. */
    fun deleteMark(id: BookmarkId) {
        viewModelScope.launch {
            bookmarks.delete(id)
            refreshMarks()
        }
    }

    /** Marks the line under the finger — as a highlight, or as a note as well. */
    fun addHighlight(line: String, position: ReadingPosition, asNote: Boolean) {
        viewModelScope.launch {
            bookmarks.addHighlight(
                bookId = bookId,
                position = position,
                text = line,
                bookTitle = _state.value.title,
                location = "page ${_state.value.page + 1}",
                asNote = asNote,
            )
            DomainEventBus.publish(DomainEvent.BookmarkCreated("highlight"))
            refreshMarks()
        }
    }

    /** Marks the page being read. */
    fun addPageBookmark() {
        viewModelScope.launch {
            bookmarks.addPageBookmark(bookId, ReadingPosition(0, 0, 0))
            DomainEventBus.publish(DomainEvent.BookmarkCreated("page"))
            refreshMarks()
        }
    }

    /** Where the reader is — written when the reader closes. */
    fun savePosition(page: Int) {
        backgroundScope.launch { books.savePosition(bookId, page) }
    }
}
