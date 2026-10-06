package com.mn.android

import android.content.Context
import android.util.Log
import com.mn.android.data.StreakSnapshotStore

/**
 * Drives `KotlinStreakActivityStore` through the whole round trip: Kotlin ->
 * Swift `JSONEncoder` -> SharedPreferences -> Swift `JSONDecoder` -> back to
 * Kotlin, then an overwrite and a deliberately corrupt document.
 *
 * All seven checks are booleans, so every label says `Ok` — a bare `=1` next to
 * a count reads as "one row", which is how the first draft of NoteProbe could
 * be misread.
 *
 * Swift side: KotlinStreakActivityStore.swift
 */
object StreakProbe {

    private const val TAG = "StreakProbe"

    /** Matches `streakProbeSlots` in KotlinStreakActivityStore.swift. */
    private const val SLOTS = 8

    private const val LOADED = 0
    private const val CURRENT_STREAK = 1
    private const val COUNT = 2
    private const val LAST_COUNTED = 3
    private const val FLAGS = 4
    private const val REPLACED = 5
    private const val CORRUPT_NIL = 6
    private const val FAILED = 7

    fun roundTrip(context: Context): String {
        StreakSnapshotStore.configure(context)

        val results = LongArray(SLOTS)
        NativeProbe.streakProbe(results)
        return results.describe().also { Log.i(TAG, it) }
    }

    /**
     * A single verdict: every check has to hold for this to say PASS, so a green
     * line cannot be mistaken for a partially green one.
     */
    private fun LongArray.describe(): String {
        if (size < SLOTS) return "streak probe malformed($size): ${joinToString(",")}"
        if (this[FAILED] != 0L) return "streak probe threw before finishing"

        val checks = mapOf(
            "loadedOk" to (this[LOADED] == 1L),
            "currentStreakOk" to (this[CURRENT_STREAK] == 1L),
            "countOk" to (this[COUNT] == 1L),
            "lastCountedOk" to (this[LAST_COUNTED] == 1L),
            "flagsOk" to (this[FLAGS] == 1L),
            "replacedOk" to (this[REPLACED] == 1L),
            "corruptNilOk" to (this[CORRUPT_NIL] == 1L),
        )
        val detail = checks.entries.joinToString(" ") { "${it.key}=${it.value}" }
        val passed = checks.values.all { it }
        return "streak blob ${if (passed) "PASS" else "FAIL"}: $detail"
    }
}
