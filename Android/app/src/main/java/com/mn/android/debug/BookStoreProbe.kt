package com.mn.android.debug

import android.content.Context
import android.util.Log
import com.mn.android.data.BookBlobStore

/**
 * Drives `KotlinBookStore` through the whole round trip: Kotlin SharedPreferences
 * -> Swift JSON -> back, plus position, cover, update and delete, plus the file
 * import path.
 *
 * Swift side: BookProbes.swift (bookStoreProbe).
 */
object BookStoreProbe {

    private const val TAG = "BookStoreProbe"

    /** Matches the slot count in BookProbes.swift. */
    private const val SLOTS = 9

    private const val SAVED = 0
    private const val COUNT = 1
    private const val TITLE = 2
    private const val POSITION = 3
    private const val COVER = 4
    private const val REPLACED = 5
    private const val DELETED = 6
    private const val FILE_READ = 7
    private const val FAILED = 8

    fun roundTrip(context: Context): String {
        BookBlobStore.configure(context)

        val results = LongArray(SLOTS)
        NativeProbe.bookStoreProbe(results)
        return results.describe().also { Log.i(TAG, it) }
    }

    private fun LongArray.describe(): String {
        if (size < SLOTS) return "book store probe malformed($size): ${joinToString(",")}"
        if (this[FAILED] != 0L) return "book store probe threw before finishing"

        val checks = mapOf(
            "savedOk" to (this[SAVED] == 1L),
            "countOk" to (this[COUNT] == 1L),
            "titleOk" to (this[TITLE] == 1L),
            "positionOk" to (this[POSITION] == 1L),
            "coverOk" to (this[COVER] == 1L),
            "replacedOk" to (this[REPLACED] == 1L),
            "deletedOk" to (this[DELETED] == 1L),
            "fileReadOk" to (this[FILE_READ] == 1L),
        )
        val detail = checks.entries.joinToString(" ") { "${it.key}=${it.value}" }
        val passed = checks.values.all { it }
        return "book store ${if (passed) "PASS" else "FAIL"}: $detail"
    }
}
