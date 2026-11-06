package com.mn.android.debug

import android.content.Context
import android.util.Log
import com.mn.android.data.BookBlobStore

/**
 * Drives the Swift FB2/TXT parsers and the pagination engine on device.
 * Pure Swift computation — Kotlin only allocates the result buffer, so no
 * storage setup is needed beyond `configure` (kept for symmetry with the
 * other probes).
 *
 * Swift side: BookProbes.swift (bookPaginationProbe).
 */
object PaginationProbe {

    private const val TAG = "PaginationProbe"

    /** Matches the slot count in BookProbes.swift. */
    private const val SLOTS = 9

    private const val FB2_CHAPTERS = 0
    private const val FB2_TITLE = 1
    private const val FB2_PARAGRAPHS = 2
    private const val TXT_PARAGRAPHS = 3
    private const val PAGES = 4
    private const val POSITION = 5
    private const val PROGRESS = 6
    private const val HEADING_PAGE = 7
    private const val FAILED = 8

    fun roundTrip(context: Context): String {
        BookBlobStore.configure(context)

        val results = LongArray(SLOTS)
        NativeProbe.bookPaginationProbe(results)
        return results.describe().also { Log.i(TAG, it) }
    }

    private fun LongArray.describe(): String {
        if (size < SLOTS) return "pagination probe malformed($size): ${joinToString(",")}"
        if (this[FAILED] != 0L) return "pagination probe threw before finishing"

        val checks = mapOf(
            "fb2ChaptersOk" to (this[FB2_CHAPTERS] == 1L),
            "fb2TitleOk" to (this[FB2_TITLE] == 1L),
            "fb2ParagraphsOk" to (this[FB2_PARAGRAPHS] == 1L),
            "txtParagraphsOk" to (this[TXT_PARAGRAPHS] == 2L),
            "pagesMultiplied" to (this[PAGES] > 1L),
            "positionRoundTripOk" to (this[POSITION] == 1L),
            "progressBoundsOk" to (this[PROGRESS] == 1L),
            "headingPageOk" to (this[HEADING_PAGE] == 1L),
        )
        val detail = checks.entries.joinToString(" ") { "${it.key}=${it.value}" }
        val passed = checks.values.all { it }
        return "pagination ${if (passed) "PASS" else "FAIL"}: $detail"
    }
}
