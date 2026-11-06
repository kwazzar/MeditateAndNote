package com.mn.android.domain.book

import java.io.InputStream

/**
 * The library and the reading session.
 *
 * The document itself never crosses the port: Swift parses and paginates it,
 * Kotlin gets flat records and the lines of one page.
 */
interface BookRepository {
    /** Every imported book, with its reading progress. */
    suspend fun readLibrary(): List<BookSummary>

    /**
     * Imports a document into the library.
     *
     * [name] is the document's file name — the extension decides the format.
     * [content] is the document's bytes; the adapter reads them on its own
     * dispatcher and closes the stream.
     */
    suspend fun importDocument(name: String, content: InputStream): Result<ImportedBook>

    /** Removes the book and everything that belongs to it. */
    suspend fun delete(id: BookId): Result<Unit>

    /** The decoded cover image, or null when the book has none. */
    suspend fun cover(id: BookId): Result<ByteArray?>

    /** Opens the book and paginates it for [layout]. */
    suspend fun open(id: BookId, layout: ReaderLayout): Result<OpenedBook>

    /** Lays the book out again for [layout] — after a font size change. */
    suspend fun repaginate(id: BookId, layout: ReaderLayout): Result<Pagination>

    /** The lines of the page the engine has laid out. */
    suspend fun page(index: Int): Result<ReaderPage>

    /** Stores where the reader is, so the book opens there next time. */
    suspend fun savePosition(id: BookId, page: Int): Result<Unit>
}
