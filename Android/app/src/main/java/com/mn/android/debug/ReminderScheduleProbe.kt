package com.mn.android.debug

import android.content.Context
import android.util.Log

/**
 * Drives the reminder schedule bridge: Swift fills the next fire dates for a
 * daily 20:00 reminder and Kotlin checks the result is well-formed.
 *
 * Swift side: `reminderScheduleProbe` in StreakInsightsBridge.swift
 */
object ReminderScheduleProbe {

    private const val TAG = "ReminderScheduleProbe"

    private const val SLOTS = 4

    private const val COUNT = 0
    private const val ORDERED = 1
    private const val SPACED = 2
    private const val FAILED = 3

    fun roundTrip(context: Context): String {
        val results = LongArray(SLOTS)
        NativeProbe.reminderScheduleProbe(results)
        return results.describe().also { Log.i(TAG, it) }
    }

    private fun LongArray.describe(): String {
        if (size < SLOTS) return "reminder schedule probe malformed($size): ${joinToString(",")}"
        if (this[FAILED] != 0L) return "reminder schedule probe threw before finishing"

        val checks = mapOf(
            "countOk" to (this[COUNT] == 1L),
            "orderedOk" to (this[ORDERED] == 1L),
            "spacedOk" to (this[SPACED] == 1L),
        )
        val detail = checks.entries.joinToString(" ") { "${it.key}=${it.value}" }
        val passed = checks.values.all { it }
        return "reminder schedule ${if (passed) "PASS" else "FAIL"}: $detail"
    }
}
