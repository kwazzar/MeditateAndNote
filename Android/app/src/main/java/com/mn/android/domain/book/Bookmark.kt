package com.mn.android.domain.book

/**
 * A mark the reader made in a book.
 *
 * One aggregate covers both kinds: a plain bookmark has no text, a highlight
 * also remembers the marked passage and can link to the note it was turned
 * into. Swift's `Bookmark`.
 */
data class Bookmark(
    val id: BookmarkId,
    val bookId: BookId,
    val position: ReadingPosition,
    /** The marked passage; empty for a plain bookmark. */
    val text: String,
    /** The note this highlight was turned into, when it was. */
    val noteId: String,
    val createdAtMillis: Long,
) {
    val isHighlight: Boolean get() = text.isNotEmpty()
}
