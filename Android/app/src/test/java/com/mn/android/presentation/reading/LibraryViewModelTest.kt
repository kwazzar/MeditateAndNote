package com.mn.android.presentation.reading

import com.mn.android.book.FakeBookRepository
import com.mn.android.presentation.reading.viewmodel.LibraryViewModel
import kotlinx.coroutines.Dispatchers
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
import java.io.ByteArrayInputStream

/**
 * The library screen's state holder: the list, the import and the delete.
 */
class LibraryViewModelTest {

    @Before
    fun setup() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun theLibraryIsEmptyBeforeAnythingIsImported() = runTest {
        val vm = LibraryViewModel(FakeBookRepository())

        assertTrue(vm.state.value.books.isEmpty())
    }

    @Test
    fun anImportedBookShowsUpInTheLibrary() = runTest {
        val vm = LibraryViewModel(FakeBookRepository())

        vm.import("Meditations.txt", ByteArrayInputStream("hello".toByteArray()))

        assertEquals(1, vm.state.value.books.size)
        assertEquals("Meditations", vm.state.value.books.first().title)
        assertFalse(vm.state.value.importFailed)
    }

    @Test
    fun aDeletedBookLeavesTheLibrary() = runTest {
        val vm = LibraryViewModel(FakeBookRepository())
        vm.import("Meditations.txt", ByteArrayInputStream("hello".toByteArray()))
        val id = vm.state.value.books.first().id

        vm.delete(id)

        assertTrue(vm.state.value.books.isEmpty())
    }

    @Test
    fun aFailedImportIsReported() = runTest {
        val failing = object : com.mn.android.domain.book.BookRepository by FakeBookRepository() {
            override suspend fun importDocument(
                name: String,
                content: java.io.InputStream,
            ): Result<com.mn.android.domain.book.ImportedBook> = Result.failure(
                IllegalStateException("cannot read")
            )
        }
        val vm = LibraryViewModel(failing)

        vm.import("Broken.txt", ByteArrayInputStream("hello".toByteArray()))

        assertTrue(vm.state.value.importFailed)
        vm.dismissImportError()
        assertFalse(vm.state.value.importFailed)
    }
}
