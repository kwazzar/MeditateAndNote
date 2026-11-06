package com.mn.android.data.book

import com.mn.android.data.BookmarksSource
import com.mn.android.data.io
import com.mn.android.data.ioResult
import com.mn.android.domain.book.BookId
import com.mn.android.domain.book.BookOperationError
import com.mn.android.domain.book.Bookmark
import com.mn.android.domain.book.BookmarkId
import com.mn.android.domain.book.BookmarkRepository
import com.mn.android.domain.book.Chapter
import com.mn.android.domain.book.ReadingPosition

/**
 * Adapts the marks bridge to [BookmarkRepository]. The bridge keeps its name
 * because the Swift side registers the JNI symbol under it.
 */
class JniBookmarkRepository(
    private val marks: BookmarksSource = BookmarksSource,
) : BookmarkRepository {

    override suspend fun readMarks(bookId: BookId): List<Bookmark> =
        io { marks.readMarks(bookId.value) }.map { mark ->
            Bookmark(
                id = BookmarkId(mark.id),
                bookId = bookId,
                position = ReadingPosition(mark.chapter, mark.block, mark.offset),
                text = mark.text,
                noteId = mark.noteId,
                createdAtMillis = mark.createdAtMillis,
            )
        }

    override suspend fun readChapters(bookId: BookId): List<Chapter> =
        io { marks.readChapters(bookId.value) }.map { chapter ->
            Chapter(chapter = chapter.chapter, title = chapter.title, page = chapter.page)
        }

    override suspend fun addPageBookmark(bookId: BookId, position: ReadingPosition): Result<Unit> =
        ioResult({ BookOperationError.SaveFailed(it) }) {
            marks.addPageBookmark(bookId.value, position.chapter, position.block, position.offset)
        }

    override suspend fun addHighlight(
        bookId: BookId,
        position: ReadingPosition,
        text: String,
        bookTitle: String,
        location: String,
        asNote: Boolean,
    ): Result<Unit> = ioResult({ BookOperationError.SaveFailed(it) }) {
        marks.addHighlight(
            bookId = bookId.value,
            chapter = position.chapter,
            block = position.block,
            offset = position.offset,
            text = text,
            bookTitle = bookTitle,
            location = location,
            asNote = asNote,
        )
    }

    override suspend fun delete(id: BookmarkId): Result<Unit> =
        ioResult({ BookOperationError.DeleteFailed(it) }) {
            marks.delete(id.value)
        }

    override suspend fun pageForPosition(position: ReadingPosition): Int =
        io { marks.pageForPosition(position.chapter, position.block, position.offset) }
}
