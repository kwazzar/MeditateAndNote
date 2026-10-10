package com.mn.android

import android.content.Context
import android.util.Log
import com.mn.android.data.StreakSnapshotStore

/**
 * Drives the streak-detail read end to end: Swift writes a known snapshot
 * (yesterday complete with times, two days ago meditation-only, today clean),
 * then fills the per-day timestamps and stats exactly the way
 * `Java_com_mn_android_data_StreakDetailSource_read` does.
 *
 * Proves the detail JNI entry point — symbol, signature, and that the -1
 * "missing half" sentinel and the stat counters survive the crossing.
 *
 * Swift side: `streakDetailProbe` in KotlinStreakActivityStore.swift
 */
object StreakDetailProbe {

    private const val TAG = "StreakDetailProbe"

    private const val SLOTS = 8

    private const val YESTERDAY_MED_TIME = 0
    private const val YESTERDAY_NOTE_TIME = 1
    private const val TWO_DAYS_NOTE_CLEARED = 2
    private const val TODAY_CLEAN = 3
    private const val CURRENT_STREAK = 4
    private const val LONGEST_STREAK = 5
    private const val TOTAL_COMPLETE = 6
    private const val FAILED = 7

    fun roundTrip(context: Context): String {
        StreakSnapshotStore.configure(context)

        val results = LongArray(SLOTS)
        NativeProbe.streakDetailProbe(results)
        return results.describe().also { Log.i(TAG, it) }
    }

    private fun LongArray.describe(): String {
        if (size < SLOTS) return "streak detail probe malformed($size): ${joinToString(",")}"
        if (this[FAILED] != 0L) return "streak detail probe threw before finishing"

        val checks = mapOf(
            "yesterdayMedTimeOk" to (this[YESTERDAY_MED_TIME] == 1L),
            "yesterdayNoteTimeOk" to (this[YESTERDAY_NOTE_TIME] == 1L),
            "twoDaysNoteCleared" to (this[TWO_DAYS_NOTE_CLEARED] == 1L),
            "todayClean" to (this[TODAY_CLEAN] == 1L),
            "currentStreakOk" to (this[CURRENT_STREAK] == 1L),
            "longestStreakOk" to (this[LONGEST_STREAK] == 1L),
            "totalCompleteOk" to (this[TOTAL_COMPLETE] == 1L),
        )
        val detail = checks.entries.joinToString(" ") { "${it.key}=${it.value}" }
        val passed = checks.values.all { it }
        return "streak detail ${if (passed) "PASS" else "FAIL"}: $detail"
    }
}
