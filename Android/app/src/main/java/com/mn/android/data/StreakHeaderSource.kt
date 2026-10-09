package com.mn.android.data

import java.time.LocalDate
import java.time.ZoneId

/**
 * Kotlin side of the streak header read.
 *
 * Kotlin computes the 7 day-start millis (calendar math for display is UI
 * work), Swift fills one flag per day from the stored `StreakSnapshot` and
 * returns the streak count. The snapshot JSON stays opaque to Kotlin — the
 * same rule as `StreakSnapshotStore`, and why the flags come back as 0/1
 * longarrays instead of a decoded shape.
 *
 * Swift side: Java_com_mn_android_data_StreakHeaderSource_read in
 * KotlinStreakActivityStore.swift.
 */
object StreakHeaderSource {

    init {
        // Generated classes load the .so from their own static initializer.
        // Home is the start destination, so it can be the first code to touch
        // JNI — force the load here, same as NativeProbe.
        Class.forName("com.mn.core.AIDraftMetric")
    }

    /**
     * Fills [medFlags] and [noteFlags] with 0/1 per day and returns the current
     * streak. [dayStartMillis] must hold start-of-day millis in the local zone,
     * oldest first. Buffers belong to Kotlin: Swift cannot replace an
     * out-param reference, so both flag arrays are allocated here.
     */
    external fun read(
        dayStartMillis: LongArray,
        medFlags: LongArray,
        noteFlags: LongArray,
    ): Long

    /** 7 day-start millis for the local zone, oldest first, today last. */
    fun last7DayStartMillis(): LongArray {
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now()
        return LongArray(7) { offset ->
            today.minusDays(6L - offset).atStartOfDay(zone).toInstant().toEpochMilli()
        }
    }

    data class DayFlags(val hasMeditation: Boolean, val hasNote: Boolean)

    data class Header(
        val currentStreak: Int,
        val dayFlags: List<DayFlags>,
    ) {
        val today: DayFlags get() = dayFlags.last()
        val isTodayComplete: Boolean get() = today.hasMeditation && today.hasNote
        val showNoteReminder: Boolean get() = today.hasMeditation && !today.hasNote
    }

    fun readHeader(): Header {
        val med = LongArray(7)
        val note = LongArray(7)
        val streak = read(last7DayStartMillis(), med, note)
        return Header(
            currentStreak = streak.toInt(),
            dayFlags = med.zip(note) { m, n -> DayFlags(m == 1L, n == 1L) },
        )
    }
}