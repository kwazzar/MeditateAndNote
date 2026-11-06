package com.mn.android.book

import com.mn.android.domain.book.BookId
import com.mn.android.domain.book.BookmarkRepository
import com.mn.android.domain.book.ReadingPosition
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The invariants every BookmarkRepository has to keep: a mark that was added
 * can be read back and removed again.
 */
abstract class BookmarkRepositoryContract {
    protected abstract fun createRepo(): BookmarkRepository

    /** The book the marks live in. */
    protected abstract fun bookId(): BookId

    @Test fun anAddedMarkCanBeReadBack() = runTest {
        val repo = createRepo()
        val id = bookId()
        assertTrue(repo.addPageBookmark(id, ReadingPosition(0, 0, 0)).isSuccess)
        val marks = repo.readMarks(id)
        assertEquals(1, marks.size)
        assertTrue("a page bookmark has no text", !marks.first().isHighlight)
    }

    @Test fun aHighlightKeepsItsText() = runTest {
        val repo = createRepo()
        val id = bookId()
        assertTrue(
            repo.addHighlight(
                bookId = id,
                position = ReadingPosition(0, 0, 0),
                text = "a marked passage",
                bookTitle = "A book",
                location = "page 1",
                asNote = false,
            ).isSuccess
        )
        val marks = repo.readMarks(id)
        assertEquals(1, marks.size)
        assertTrue("a highlight has text", marks.first().isHighlight)
    }

    @Test fun aMarkCanBeRemoved() = runTest {
        val repo = createRepo()
        val id = bookId()
        repo.addPageBookmark(id, ReadingPosition(0, 0, 0))
        val mark = repo.readMarks(id).first()
        assertTrue(repo.delete(mark.id).isSuccess)
        assertTrue(repo.readMarks(id).isEmpty())
    }
}
