package com.mn.android.data

import java.time.LocalDate

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
        tzOffsetMinutes: Int,
    ): Long

    /** 7 day-start millis for the local zone, oldest first, today last. */
    fun last7DayStartMillis(): LongArray {
        val today = LocalDate.now()
        val offsetMillis = currentUtcOffsetMillis()
        return LongArray(7) { offset ->
            localDayStartMillis(today.minusDays(6L - offset), offsetMillis)
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
        // Swift-on-Android resolves TimeZone.current to UTC (no tzdata), so the
        // JVM passes its current offset — same rule as ReminderScheduleSource.
        val tzOffsetMinutes = (currentUtcOffsetMillis() / 60_000).toInt()
        val streak = read(last7DayStartMillis(), med, note, tzOffsetMinutes)
        return Header(
            currentStreak = streak.toInt(),
            dayFlags = med.zip(note) { m, n -> DayFlags(m == 1L, n == 1L) },
        )
    }
}

/** Offset the JNI bridge expects: the JVM's offset right now, not at midnight. */
internal fun currentUtcOffsetMillis(): Long =
    java.util.TimeZone.getDefault().getOffset(System.currentTimeMillis()).toLong()

/**
 * Start-of-day millis for [date], bucketed with a fixed [offsetMillis].
 *
 * Swift-on-Android has no tzdata and resolves `TimeZone.current` to UTC, so
 * every streak JNI call passes the JVM's *current* offset instead. Kotlin must
 * use that same fixed offset here: `ZoneId` rules would pick the offset in
 * force at midnight, which on a DST-transition day is one hour off and drops
 * today's mark into the neighbouring cell.
 *
 * ponytail: fixed offset, so a day split by a DST change can bucket an
 * activity written before the change into the adjacent cell. Pass a real zone
 * id (or ship tzdata to Swift) if that matters.
 */
internal fun localDayStartMillis(date: LocalDate, offsetMillis: Long): Long =
    date.toEpochDay() * 86_400_000L - offsetMillis
