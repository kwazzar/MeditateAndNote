package com.mn.android.book

import com.mn.android.domain.book.BookId
import com.mn.android.domain.book.BookRepository
import com.mn.android.domain.book.BookSummary
import com.mn.android.domain.book.ImportedBook
import com.mn.android.domain.book.OpenedBook
import com.mn.android.domain.book.Pagination
import com.mn.android.domain.book.ReaderLayout
import com.mn.android.domain.book.ReaderPage
import com.mn.android.domain.book.ReadingPosition
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update
import java.io.InputStream

class FakeBookRepository : BookRepository {

    private val books = MutableStateFlow<List<BookSummary>>(emptyList())

    override suspend fun readLibrary(): List<BookSummary> = books.value

    override suspend fun importDocument(name: String, content: InputStream): Result<ImportedBook> {
        val format = name.substringAfterLast('.', "txt").lowercase()
        val id = BookId("fake-book-${books.value.size + 1}")
        books.update {
            it + BookSummary(
                id = id,
                title = name.substringBeforeLast('.'),
                author = "",
                format = format,
                progressPerMille = 0,
            )
        }
        return Result.success(ImportedBook(id, format))
    }

    override suspend fun delete(id: BookId): Result<Unit> {
        books.update { it.filterNot { book -> book.id == id } }
        return Result.success(Unit)
    }

    override suspend fun cover(id: BookId): Result<ByteArray?> = Result.success(null)

    override suspend fun open(id: BookId, layout: ReaderLayout): Result<OpenedBook> =
        Result.success(OpenedBook(title = "Fake book", pageCount = 1, page = 0))

    override suspend fun repaginate(id: BookId, layout: ReaderLayout): Result<Pagination> =
        Result.success(Pagination(pageCount = 1, page = 0))

    override suspend fun page(index: Int): Result<ReaderPage> = Result.success(
        ReaderPage(
            lines = listOf("Line one", "Line two"),
            positions = listOf(ReadingPosition(0, 0, 0), ReadingPosition(0, 0, 1)),
            progress = 0.0,
        )
    )

    override suspend fun savePosition(id: BookId, page: Int): Result<Unit> = Result.success(Unit)
}
