package com.mn.android.presentation.reading

import com.mn.android.book.FakeBookRepository
import com.mn.android.book.FakeBookmarkRepository
import com.mn.android.domain.book.BookId
import com.mn.android.domain.book.BookRepository
import com.mn.android.domain.book.OpenedBook
import com.mn.android.domain.book.ReaderLayout
import com.mn.android.domain.book.ReaderPage
import com.mn.android.domain.book.ReadingPosition
import com.mn.android.presentation.reading.viewmodel.ReaderViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * The reader's state holder: the book opens, the page turns, the marks land.
 */
class ReaderViewModelTest {

    private val background = CoroutineScope(SupervisorJob() + Dispatchers.Unconfined)

    @Before
    fun setup() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun theBookOpensWithItsFirstPage() = runTest {
        val vm = reader(FakeBookRepository())

        vm.open(layout())

        assertEquals("Fake book", vm.state.value.title)
        assertEquals(1, vm.state.value.pageCount)
        assertEquals(listOf("Line one", "Line two"), vm.state.value.lines)
        assertFalse(vm.state.value.loadFailed)
    }

    @Test
    fun aBookThatCannotBeOpenedIsReported() = runTest {
        val failing = object : BookRepository by FakeBookRepository() {
            override suspend fun open(id: BookId, layout: ReaderLayout): Result<OpenedBook> =
                Result.failure(IllegalStateException("no such book"))
        }
        val vm = reader(failing)

        vm.open(layout())

        assertTrue(vm.state.value.loadFailed)
    }

    @Test
    fun thePageTurnIsClampedToTheBook() = runTest {
        val vm = reader(FakeBookRepository())
        vm.open(layout())

        vm.showPage(99, scrollMode = false)

        assertEquals(0, vm.state.value.page)
    }

    @Test
    fun aHighlightBecomesAMark() = runTest {
        val marks = FakeBookmarkRepository()
        val vm = reader(FakeBookRepository(), marks)
        vm.open(layout())

        vm.addHighlight("Line one", ReadingPosition(0, 0, 0), asNote = true)

        assertEquals(1, vm.state.value.marks.size)
        assertEquals("fake-note", vm.state.value.marks.first().noteId)
    }

    @Test
    fun aPageBookmarkBecomesAMark() = runTest {
        val marks = FakeBookmarkRepository()
        val vm = reader(FakeBookRepository(), marks)
        vm.open(layout())

        vm.addPageBookmark()

        assertEquals(1, vm.state.value.marks.size)
    }

    private fun reader(
        books: BookRepository,
        marks: FakeBookmarkRepository = FakeBookmarkRepository(),
    ) = ReaderViewModel(
        bookId = BookId("book-1"),
        books = books,
        bookmarks = marks,
        backgroundScope = background,
    )

    private fun layout() = ReaderLayout(fontSize = 16.0, width = 100.0, height = 200.0, widthScale = 1.0)
}
