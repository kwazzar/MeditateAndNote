package com.mn.android.data

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
        val obj = JSONObject(openNative(id, fontSize, width, height, widthScale))
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
