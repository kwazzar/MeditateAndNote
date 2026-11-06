package com.mn.android.book

import com.mn.android.domain.book.BookRepository
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream

/**
 * The invariants every BookRepository has to keep, whatever backs it: an
 * imported book shows up in the library, and a deleted one does not.
 */
abstract class BookRepositoryContract {
    protected abstract fun createRepo(): BookRepository

    /** A document the importer accepts: the extension decides the format. */
    protected fun document(name: String = "contract.txt") =
        ByteArrayInputStream(
            """
            The quiet mind observes its own breath, and every thought passes.

            A second paragraph, so the parser has more than one block to lay
            out and the book is not a single empty line.
            """.trimIndent().toByteArray()
        )

    @Test fun importPutsTheBookInTheLibrary() = runTest {
        val repo = createRepo()
        val imported = repo.importDocument("contract.txt", document())
        assertTrue("import must succeed: ${imported.exceptionOrNull()}", imported.isSuccess)
        val id = imported.getOrThrow().id
        assertTrue(
            "the imported book must be in the library",
            repo.readLibrary().any { it.id == id },
        )
    }

    @Test fun deleteRemovesTheBook() = runTest {
        val repo = createRepo()
        val id = repo.importDocument("contract.txt", document()).getOrThrow().id
        assertTrue(repo.delete(id).isSuccess)
        assertTrue(
            "the deleted book must be gone",
            repo.readLibrary().none { it.id == id },
        )
    }
}
