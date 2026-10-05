package com.mn.android

import android.content.Context
import android.util.Log
import com.mn.android.data.SharedPrefsReminderSettingsStore

/**
 * Kotlin's way of reaching the Swift `KotlinReminderSettingsStore`, which in turn
 * reaches back into `SharedPrefsReminderSettingsStore`.
 *
 * The round trip is driven from Kotlin so it proves the whole cycle rather than
 * one direction: Kotlin -> Swift store -> Kotlin persistence -> Swift load -> back
 * to Kotlin. A test that only saved would pass with a store that never read
 * anything back.
 *
 * Values come back as `long[]` rather than a formatted string because Swift hands
 * a Java array back, not a string. Formatting happens here, where the array is.
 *
 * Swift side: KotlinReminderSettingsStore.swift
 */
object ReminderSettingsProbe {

    private const val TAG = "ReminderSettingsProbe"

    private const val ENABLED = 0
    private const val HOUR = 1
    private const val MINUTE = 2
    private const val WEEKDAY_COUNT = 3

    /**
     * Saves through Swift and reads back.
     *
     * [hour] is passed out of range on purpose: `ReminderSettings.init` clamps it
     * to 0...23, so the value that comes back must be 23. If clamping happened on
     * the Kotlin side instead, this would return 99 and the invariant would live
     * in two places.
     */
    fun roundTrip(context: Context): String {
        SharedPrefsReminderSettingsStore.configure(context)

        val buffer = LongArray(BUFFER_SIZE)
        NativeProbe.saveReminders(true, 99, 7, longArrayOf(1, 3, 5), buffer)
        val afterSave = buffer.describe()
        val reread = LongArray(BUFFER_SIZE).also { NativeProbe.loadReminders(it) }.describe()
        val result = "save->load $afterSave reload $reread"
        // print from Swift does not reach logcat on this device, so the result is
        // logged from the Kotlin side that received it.
        Log.i(TAG, result)
        return result
    }

    /**
     * Must match `settingsBufferSize` in KotlinReminderSettingsStore.swift:
     * Swift writes into this array in place and will not grow it.
     */
    const val BUFFER_SIZE = 32

    private fun LongArray.describe(): String {
        if (size < WEEKDAY_COUNT + 1) return "malformed($size): ${joinToString(",")}"
        val weekdays = copyOfRange(WEEKDAY_COUNT + 1, WEEKDAY_COUNT + 1 + this[WEEKDAY_COUNT].toInt())
        return "enabled=${this[ENABLED]} hour=${this[HOUR]} minute=${this[MINUTE]} weekdays=${weekdays.joinToString(",")}"
    }
}