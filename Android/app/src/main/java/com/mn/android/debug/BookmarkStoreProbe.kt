package com.mn.android.debug

import android.content.Context
import android.util.Log
import com.mn.android.data.BookmarkBlobStore

/**
 * Drives `KotlinBookmarkStore` through the whole round trip: Swift writes the
 * marks, Kotlin keeps them as one JSON document in SharedPreferences, Swift
 * reads them back and deletes one.
 *
 * Swift side: BookBookmarkProbes.swift (bookmarkProbe).
 */
object BookmarkStoreProbe {

    private const val TAG = "BookmarkStoreProbe"

    /** Matches the slot count in BookBookmarkProbes.swift. */
    private const val SLOTS = 7

    private const val SAVED = 0
    private const val COUNT = 1
    private const val TEXT = 2
    private const val POSITION = 3
    private const val NOTE_LINK = 4
    private const val DELETED = 5
    private const val FAILED = 6

    fun roundTrip(context: Context): String {
        BookmarkBlobStore.configure(context)

        val results = LongArray(SLOTS)
        NativeProbe.bookmarkProbe(results)
        return results.describe().also { Log.i(TAG, it) }
    }

    private fun LongArray.describe(): String {
        if (size < SLOTS) return "bookmark probe malformed($size): ${joinToString(",")}"
        if (this[FAILED] != 0L) return "bookmark probe threw before finishing"

        val checks = mapOf(
            "savedOk" to (this[SAVED] == 1L),
            "countOk" to (this[COUNT] == 1L),
            "textOk" to (this[TEXT] == 1L),
            "positionOk" to (this[POSITION] == 1L),
            "noteLinkOk" to (this[NOTE_LINK] == 1L),
            "deletedOk" to (this[DELETED] == 1L),
        )
        val detail = checks.entries.joinToString(" ") { "${it.key}=${it.value}" }
        val passed = checks.values.all { it }
        return "bookmark store ${if (passed) "PASS" else "FAIL"}: $detail"
    }
}
