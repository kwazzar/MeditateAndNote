package com.mn.android.data

import org.json.JSONObject

/**
 * Kotlin side of the reader's marks and table of contents.
 *
 * Wire formats are defined by the Swift thunks (`BookReaderBridge.swift`),
 * not by the Core schema: Kotlin sees flat display records, never a
 * Core-owned `Bookmark` document.
 */
object BookmarksSource {

    init {
        Class.forName("com.mn.core.AIDraftMetric")
    }

    data class Mark(
        val id: String,
        val chapter: Int,
        val block: Int,
        val offset: Int,
        val text: String,
        val noteId: String,
        val createdAtMillis: Long,
    ) {
        val isHighlight: Boolean get() = text.isNotEmpty()
    }

    data class Chapter(
        val chapter: Int,
        val title: String,
        val page: Int,
    )

    fun readMarks(bookId: String): List<Mark> {
        val obj = JSONObject(readNative(bookId))
        val marks = obj.getJSONArray("marks")
        return (0 until marks.length()).map { i ->
            val item = marks.getJSONObject(i)
            Mark(
                id = item.getString("id"),
                chapter = item.getInt("chapter"),
                block = item.getInt("block"),
                offset = item.getInt("offset"),
                text = item.optString("text", ""),
                noteId = item.optString("noteId", ""),
                createdAtMillis = item.optDouble("createdAt", 0.0).toLong(),
            )
        }
    }

    fun addPageBookmark(bookId: String, chapter: Int, block: Int, offset: Int): String {
        return addPageNative(bookId, chapter, block, offset)
    }

    fun addHighlight(
        bookId: String,
        chapter: Int,
        block: Int,
        offset: Int,
        text: String,
        bookTitle: String,
        location: String,
        asNote: Boolean,
    ): String {
        return addHighlightNative(bookId, chapter, block, offset, text, bookTitle, location, asNote)
    }

    fun delete(markId: String) {
        deleteNative(markId)
    }

    fun readChapters(bookId: String): List<Chapter> {
        val obj = JSONObject(tocNative(bookId))
        val chapters = obj.getJSONArray("chapters")
        return (0 until chapters.length()).map { i ->
            val item = chapters.getJSONObject(i)
            Chapter(
                chapter = item.getInt("chapter"),
                title = item.getString("title"),
                page = item.getInt("page"),
            )
        }
    }

    /** The page a logical position resolves to in the current layout. */
    fun pageForPosition(chapter: Int, block: Int, offset: Int): Int {
        return pageForPositionNative(chapter, block, offset)
    }

    // JNI entry points, Swift side: BookReaderBridge.swift
    private external fun readNative(bookId: String): String
    private external fun addPageNative(bookId: String, chapter: Int, block: Int, offset: Int): String
    private external fun addHighlightNative(
        bookId: String,
        chapter: Int,
        block: Int,
        offset: Int,
        text: String,
        bookTitle: String,
        location: String,
        asNote: Boolean,
    ): String

    private external fun deleteNative(markId: String)
    private external fun tocNative(bookId: String): String
    private external fun pageForPositionNative(chapter: Int, block: Int, offset: Int): Int
}
