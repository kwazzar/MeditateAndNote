package com.mn.android.book

import com.mn.android.domain.book.BookId
import com.mn.android.domain.book.Bookmark
import com.mn.android.domain.book.BookmarkId
import com.mn.android.domain.book.BookmarkRepository
import com.mn.android.domain.book.Chapter
import com.mn.android.domain.book.ReadingPosition
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

class FakeBookmarkRepository : BookmarkRepository {

    private val marks = MutableStateFlow<List<Bookmark>>(emptyList())
    private val chapters = MutableStateFlow<List<Chapter>>(emptyList())

    override suspend fun readMarks(bookId: BookId): List<Bookmark> =
        marks.value.filter { it.bookId == bookId }

    override suspend fun readChapters(bookId: BookId): List<Chapter> = chapters.value

    override suspend fun addPageBookmark(bookId: BookId, position: ReadingPosition): Result<Unit> {
        marks.update {
            it + Bookmark(
                id = BookmarkId("fake-mark-${it.size + 1}"),
                bookId = bookId,
                position = position,
                text = "",
                noteId = "",
                createdAtMillis = 0L,
            )
        }
        return Result.success(Unit)
    }

    override suspend fun addHighlight(
        bookId: BookId,
        position: ReadingPosition,
        text: String,
        bookTitle: String,
        location: String,
        asNote: Boolean,
    ): Result<Unit> {
        marks.update {
            it + Bookmark(
                id = BookmarkId("fake-mark-${it.size + 1}"),
                bookId = bookId,
                position = position,
                text = text,
                noteId = if (asNote) "fake-note" else "",
                createdAtMillis = 0L,
            )
        }
        return Result.success(Unit)
    }

    override suspend fun delete(id: BookmarkId): Result<Unit> {
        marks.update { it.filterNot { mark -> mark.id == id } }
        return Result.success(Unit)
    }

    override suspend fun pageForPosition(position: ReadingPosition): Int = 0
}
