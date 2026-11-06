package com.mn.android.data.book

import com.mn.android.data.BookSource
import com.mn.android.data.ReaderSource
import com.mn.android.data.asFileName
import com.mn.android.data.detectBookFormat
import com.mn.android.data.io
import com.mn.android.data.ioResult
import com.mn.android.domain.book.BookId
import com.mn.android.domain.book.BookOperationError
import com.mn.android.domain.events.DomainEvent
import com.mn.android.domain.events.DomainEventBus
import com.mn.android.domain.book.BookRepository
import com.mn.android.domain.book.BookSummary
import com.mn.android.domain.book.ImportedBook
import com.mn.android.domain.book.OpenedBook
import com.mn.android.domain.book.Pagination
import com.mn.android.domain.book.ReaderLayout
import com.mn.android.domain.book.ReaderPage
import com.mn.android.domain.book.ReadingPosition
import java.io.File
import java.io.InputStream

/**
 * Adapts the book JNI bridges to [BookRepository].
 *
 * The bridges keep their own names because the Swift side registers the JNI
 * symbols under them. The document never crosses: Swift parses and paginates
 * it, Kotlin gets flat records and the lines of one page.
 */
class JniBookRepository(
    /** Where a picked document is copied before the importer reads it. */
    private val cacheDir: File,
    private val library: BookSource = BookSource,
    private val reader: ReaderSource = ReaderSource,
    private val bus: DomainEventBus = DomainEventBus,
) : BookRepository {

    override suspend fun readLibrary(): List<BookSummary> =
        io { library.readLibrary() }.map { record ->
            BookSummary(
                id = BookId(record.id),
                title = record.title,
                author = record.author,
                format = record.format,
                progressPerMille = record.progressPerMille,
            )
        }

    /**
     * The picked document is copied into the cache first: the Swift importer
     * reads a file path, and a content uri is not a file at all.
     */
    override suspend fun importDocument(name: String, content: InputStream): Result<ImportedBook> =
        ioResult({ BookOperationError.ImportFailed(it) }) {
            try {
                val format = detectBookFormat(name) ?: error("unsupported format")
                val temp = File(cacheDir, name.asFileName())
                try {
                    content.use { input -> temp.outputStream().use { output -> input.copyTo(output) } }
                    val imported = ImportedBook(
                        id = BookId(library.import(temp.absolutePath, format)),
                        format = format,
                    )
                    // The repository announces the mutation, so whoever listens
                    // does not have to remember to publish it.
                    bus.publish(DomainEvent.BookImported(format))
                    imported
                } finally {
                    temp.delete()
                }
            } finally {
                // The stream comes from the caller: it is closed even when the
                // format turns out to be unsupported.
                content.close()
            }
        }

    override suspend fun delete(id: BookId): Result<Unit> =
        ioResult({ BookOperationError.DeleteFailed(it) }) {
            library.delete(id.value)
        }

    override suspend fun cover(id: BookId): Result<ByteArray?> =
        ioResult({ BookOperationError.LoadFailed(it) }) {
            library.cover(id.value)
        }

    override suspend fun open(id: BookId, layout: ReaderLayout): Result<OpenedBook> =
        ioResult({ BookOperationError.OpenFailed(it) }) {
            val opened = reader.open(id.value, layout.fontSize, layout.width, layout.height, layout.widthScale)
            OpenedBook(title = opened.title, pageCount = opened.pageCount, page = opened.page)
        }

    override suspend fun repaginate(id: BookId, layout: ReaderLayout): Result<Pagination> =
        ioResult({ BookOperationError.OpenFailed(it) }) {
            val (pageCount, page) = reader.repaginate(
                id.value, layout.fontSize, layout.width, layout.height, layout.widthScale
            )
            Pagination(pageCount, page)
        }

    override suspend fun page(index: Int): Result<ReaderPage> =
        ioResult({ BookOperationError.LoadFailed(it) }) {
            val (lines, positions, progress) = reader.page(index)
            ReaderPage(
                lines = lines,
                positions = positions.map { ReadingPosition(it.chapter, it.block, it.offset) },
                progress = progress,
            )
        }

    override suspend fun savePosition(id: BookId, page: Int): Result<Unit> =
        ioResult({ BookOperationError.SaveFailed(it) }) {
            reader.savePosition(id.value, page)
        }
}
