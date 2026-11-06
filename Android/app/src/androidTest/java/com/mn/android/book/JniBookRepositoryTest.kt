package com.mn.android.book

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.mn.android.data.BookBlobStore
import com.mn.android.data.BookmarkBlobStore
import com.mn.android.data.book.JniBookmarkRepository
import com.mn.android.data.book.JniBookRepository
import com.mn.android.domain.book.BookId
import com.mn.android.domain.book.BookRepository
import com.mn.android.domain.book.BookmarkRepository
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayInputStream

/**
 * The book path against a real device. The importer needs the blob stores:
 * they hold the library and the stored files.
 */
@RunWith(AndroidJUnit4::class)
class JniBookRepositoryTest : BookRepositoryContract() {

    private lateinit var repo: JniBookRepository

    @Before
    fun configureStores() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        BookBlobStore.configure(context)
        BookmarkBlobStore.configure(context)
        repo = JniBookRepository(cacheDir = context.cacheDir)
    }

    override fun createRepo(): BookRepository = repo
}

/**
 * The marks path against a real device. A mark belongs to a book, so the test
 * imports one first — the marks are then read and removed from it.
 */
@RunWith(AndroidJUnit4::class)
class JniBookmarkRepositoryTest : BookmarkRepositoryContract() {

    private lateinit var bookRepo: JniBookRepository
    private lateinit var repo: JniBookmarkRepository
    private var importedId: BookId? = null

    @Before
    fun configureStores() {
        runBlocking {
            val context = InstrumentationRegistry.getInstrumentation().targetContext
            BookBlobStore.configure(context)
            BookmarkBlobStore.configure(context)
            bookRepo = JniBookRepository(cacheDir = context.cacheDir)
            repo = JniBookmarkRepository()
            importedId = bookRepo.importDocument(
                "contract.txt",
                ByteArrayInputStream(
                    """
                    The quiet mind observes its own breath, and every thought passes.

                    A second paragraph, so the parser has more than one block.
                    """.trimIndent().toByteArray()
                ),
            ).getOrThrow().id
        }
    }

    @After
    fun cleanUp() {
        runBlocking { importedId?.let { bookRepo.delete(it) } }
    }

    override fun createRepo(): BookmarkRepository = repo

    override fun bookId(): BookId = importedId ?: error("the book was not imported")
}
