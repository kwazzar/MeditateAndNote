package com.mn.android.domain.book

/**
 * The reader's marks and the table of contents.
 *
 * A highlight can be turned into a note; the mark keeps the link to it.
 */
interface BookmarkRepository {
    /** Every mark in the book. */
    suspend fun readMarks(bookId: BookId): List<Bookmark>

    /** The book's table of contents. */
    suspend fun readChapters(bookId: BookId): List<Chapter>

    /** Adds a plain page bookmark. */
    suspend fun addPageBookmark(bookId: BookId, position: ReadingPosition): Result<Unit>

    /**
     * Adds a highlight.
     *
     * [asNote] turns the marked passage into a note as well; [location] is the
     * human label the note carries ("page 12").
     */
    suspend fun addHighlight(
        bookId: BookId,
        position: ReadingPosition,
        text: String,
        bookTitle: String,
        location: String,
        asNote: Boolean,
    ): Result<Unit>

    /** Removes the mark. */
    suspend fun delete(id: BookmarkId): Result<Unit>

    /** The page a logical position resolves to in the current layout. */
    suspend fun pageForPosition(position: ReadingPosition): Int
}
