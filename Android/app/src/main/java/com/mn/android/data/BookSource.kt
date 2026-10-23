package com.mn.android.data

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.io.InputStream
import org.json.JSONObject

/**
 * Kotlin side of the book library + reader reads.
 *
 * Wire formats are defined by the Swift thunks (`BookReaderBridge.swift`), not
 * by the Core schema: the library read returns a flat display record per book,
 * the reader read returns page lines as plain strings. Kotlin never sees a
 * Core-owned `Book` document.
 */
object BookSource {

    init {
        // First JNI touch may happen on the Reading tab.
        Class.forName("com.mn.core.AIDraftMetric")
    }

    data class BookRecord(
        val id: String,
        val title: String,
        val author: String,
        val format: String,
        val progressPerMille: Int,
    )

    fun readLibrary(): List<BookRecord> {
        val books = JSONObject(read()).getJSONArray("books")
        return (0 until books.length()).map { i ->
            val obj = books.getJSONObject(i)
            BookRecord(
                id = obj.getString("id"),
                title = obj.getString("title"),
                author = obj.optString("author", ""),
                format = obj.getString("format"),
                progressPerMille = obj.getInt("progress"),
            )
        }
    }

    /** Returns the new book id, or throws on failure. */
    fun import(srcPath: String, format: String): String {
        val obj = JSONObject(importNative(srcPath, format))
        val error = obj.optString("error", "")
        require(error.isEmpty()) { error }
        return obj.getString("id")
    }

    /**
     * The stored format for a file name, or null when the format is not
     * supported. The extension decides — a MIME type ("text/plain") has none,
     * and guessing from it imported every text book as FB2.
     *
     * The same rule lives in the domain (`BookFormat`, used by the iOS
     * importer); Kotlin cannot call into the Core package directly, so it
     * repeats it here for the JNI call.
     */
    private fun detectFormat(fileName: String): String? {
        return when (fileName.substringAfterLast('.', "").lowercase()) {
            "fb2" -> "fb2"
            "epub" -> "epub"
            "txt", "md", "markdown" -> "txt"
            else -> null
        }
    }

    /**
     * Copies a picked document into the library and returns the new book id.
     * Used by the in-app importer and by the file-manager "open with" path.
     */
    fun importDocument(context: Context, uri: Uri): String {
        val name = displayName(context, uri)
        val format = detectFormat(name) ?: error("unsupported format")
        val temp = File(context.cacheDir, name.asFileName())
        openStream(context, uri)?.use { input ->
            temp.outputStream().use { output -> input.copyTo(output) }
        } ?: error("cannot read picked file")
        try {
            // The temp file carries the original name: the title is derived
            // from it on the Swift side.
            return import(temp.absolutePath, format)
        } finally {
            temp.delete()
        }
    }

    /** The document's real name — the MIME type carries no extension. */
    private fun displayName(context: Context, uri: Uri): String {
        if (uri.scheme != "file") {
            context.contentResolver
                .query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0 && cursor.moveToFirst()) {
                        return cursor.getString(index) ?: "book"
                    }
                }
        }
        return uri.lastPathSegment ?: "book"
    }

    private fun openStream(context: Context, uri: Uri): InputStream? =
        if (uri.scheme == "file") {
            uri.path?.let { File(it).inputStream() }
        } else {
            context.contentResolver.openInputStream(uri)
        }

    fun delete(id: String) {
        deleteNative(id)
    }

    /** Decoded cover bytes, or null. */
    fun cover(id: String): ByteArray? {
        val base64 = coverNative(id)
        if (base64.isEmpty()) return null
        return android.util.Base64.decode(base64, android.util.Base64.DEFAULT)
    }

    // JNI entry points, Swift side: BookReaderBridge.swift
    private external fun read(): String
    private external fun importNative(srcPath: String, format: String): String
    private external fun deleteNative(id: String)
    private external fun coverNative(id: String): String
}

object ReaderSource {

    init {
        Class.forName("com.mn.core.AIDraftMetric")
    }

    data class OpenedBook(val title: String, val pageCount: Int, val page: Int)

    fun open(
        id: String,
        fontSize: Double,
        width: Double,
        height: Double,
        widthScale: Double,
    ): OpenedBook {
        // The native side answers null when the file cannot be parsed.
        val obj = JSONObject(openNative(id, fontSize, width, height, widthScale) ?: error("book could not be opened"))
        return OpenedBook(
            title = obj.getString("title"),
            pageCount = obj.getInt("pageCount"),
            page = obj.getInt("page"),
        )
    }

    /** (pageCount, page the reader should land on). */
    fun repaginate(
        id: String,
        fontSize: Double,
        width: Double,
        height: Double,
        widthScale: Double,
    ): Pair<Int, Int> {
        val obj = JSONObject(repaginateNative(id, fontSize, width, height, widthScale))
        return obj.getInt("pageCount") to obj.getInt("page")
    }

    /** A logical position inside a page (chapter, block, character offset). */
    data class LinePosition(val chapter: Int, val block: Int, val offset: Int)

    /** (page lines, their positions, progress 0..1) for the cached layout. */
    fun page(index: Int): Triple<List<String>, List<LinePosition>, Double> {
        val obj = JSONObject(pageNative(index))
        val lines = obj.getJSONArray("lines")
        val positions = obj.getJSONArray("positions")
        return Triple(
            (0 until lines.length()).map { lines.getString(it) },
            (0 until positions.length()).map { i ->
                val item = positions.getJSONObject(i)
                LinePosition(item.getInt("chapter"), item.getInt("block"), item.getInt("offset"))
            },
            obj.getDouble("progress"),
        )
    }

    fun savePosition(id: String, page: Int) {
        savePositionNative(id, page)
    }

    private external fun openNative(
        id: String,
        fontSize: Double,
        width: Double,
        height: Double,
        widthScale: Double,
    ): String

    private external fun repaginateNative(
        id: String,
        fontSize: Double,
        width: Double,
        height: Double,
        widthScale: Double,
    ): String
    private external fun pageNative(index: Int): String
    private external fun savePositionNative(id: String, page: Int)
}

/** A safe cache file name that keeps letters (Cyrillic included). */
private fun String.asFileName(): String =
    replace(Regex("[^\\p{L}\\p{N}._ -]"), "_").take(120).ifBlank { "book" }
