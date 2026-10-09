package com.mn.android

import android.content.Context
import android.util.Log
import com.mn.android.data.StreakSnapshotStore

/**
 * Drives the home-screen header read end to end: Swift writes a known
 * snapshot through `KotlinStreakActivityStore`, then fills the per-day flags
 * exactly the way `Java_com_mn_android_data_StreakHeaderSource_read` does.
 *
 * This proves the newest JNI entry point: symbol name, signature, and that
 * Swift and Kotlin agree on what "yesterday" means. Every label says `Ok`,
 * same as StreakProbe — a bare `=1` reads as "one row".
 *
 * Swift side: `streakHeaderProbe` in KotlinStreakActivityStore.swift
 */
object StreakHeaderProbe {

    private const val TAG = "StreakHeaderProbe"

    private const val SLOTS = 7

    private const val STREAK = 0
    private const val YESTERDAY_MED = 1
    private const val YESTERDAY_NOTE = 2
    private const val TWO_DAYS_MED = 3
    private const val TWO_DAYS_NOTE = 4
    private const val TODAY_CLEAN = 5
    private const val FAILED = 6

    fun roundTrip(context: Context): String {
        StreakSnapshotStore.configure(context)

        val results = LongArray(SLOTS)
        NativeProbe.streakHeaderProbe(results)
        return results.describe().also { Log.i(TAG, it) }
    }

    private fun LongArray.describe(): String {
        if (size < SLOTS) return "streak header probe malformed($size): ${joinToString(",")}"
        if (this[FAILED] != 0L) return "streak header probe threw before finishing"

        // Two days ago is meditation-only, so the note flag must be 0 — same
        // for yesterday's labels being both 1 on one line or two separate ones.
        val checks = mapOf(
            "streakOk" to (this[STREAK] == 1L),
            "yesterdayMedOk" to (this[YESTERDAY_MED] == 1L),
            "yesterdayNoteOk" to (this[YESTERDAY_NOTE] == 1L),
            "twoDaysMedOk" to (this[TWO_DAYS_MED] == 1L),
            "twoDaysNoteCleared" to (this[TWO_DAYS_NOTE] == 0L),
            "todayClean" to (this[TODAY_CLEAN] == 0L),
        )
        val detail = checks.entries.joinToString(" ") { "${it.key}=${it.value}" }
        val passed = checks.values.all { it }
        return "streak header ${if (passed) "PASS" else "FAIL"}: $detail"
    }
}