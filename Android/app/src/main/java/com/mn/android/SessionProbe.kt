package com.mn.android

import android.content.Context
import android.util.Log
import com.mn.android.data.SessionBlobStore

/**
 * Drives `KotlinMeditationSessionStore` through the whole round trip: Kotlin ->
 * Swift `JSONEncoder` -> SQLite -> Swift `JSONDecoder` -> back to Kotlin, then
 * the day-window query, the ordering, and deletion.
 *
 * All eight checks are booleans labelled `Ok`, matching StreakProbe: a bare
 * `=1` next to a count reads as "one row", which is what made the first
 * NoteProbe label ambiguous.
 *
 * Swift side: KotlinMeditationSessionStore.swift
 */
object SessionProbe {

    private const val TAG = "SessionProbe"

    /** Matches `sessionProbeSlots` in KotlinMeditationSessionStore.swift. */
    private const val SLOTS = 8

    private const val DAY_ONE = 0
    private const val DAY_TWO = 1
    private const val UNRELATED = 2
    private const val DISTINCT_DAYS = 3
    private const val ORDER = 4
    private const val DURATION = 5
    private const val AFTER_DELETE = 6
    private const val FAILED = 7

    fun roundTrip(context: Context): String {
        SessionBlobStore.configure(context)

        val results = LongArray(SLOTS)
        NativeProbe.sessionProbe(results)
        return results.describe().also { Log.i(TAG, it) }
    }

    /**
     * A single verdict: every check has to hold for this to say PASS, so a green
     * line cannot be mistaken for a partially green one.
     */
    private fun LongArray.describe(): String {
        if (size < SLOTS) return "session probe malformed($size): ${joinToString(",")}"
        if (this[FAILED] != 0L) return "session probe threw before finishing"

        val checks = mapOf(
            "dayOneOk" to (this[DAY_ONE] == 1L),
            "dayTwoOk" to (this[DAY_TWO] == 1L),
            "unrelatedOk" to (this[UNRELATED] == 1L),
            "distinctDaysOk" to (this[DISTINCT_DAYS] == 1L),
            "orderOk" to (this[ORDER] == 1L),
            "durationOk" to (this[DURATION] == 1L),
            "afterDeleteOk" to (this[AFTER_DELETE] == 1L),
        )
        val detail = checks.entries.joinToString(" ") { "${it.key}=${it.value}" }
        val passed = checks.values.all { it }
        return "session blob ${if (passed) "PASS" else "FAIL"}: $detail"
    }
}
