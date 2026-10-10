package com.mn.android.data

import java.time.LocalDate
import java.time.ZoneId

/**
 * Kotlin side of the streak detail read (stats header + month grid).
 *
 * Same split as [StreakHeaderSource]: Kotlin owns the calendar math (which
 * millis a cell is) and the day-state derivation; Swift reads the stored
 * `StreakSnapshot` and fills the timestamp arrays. The snapshot JSON stays
 * opaque to Kotlin.
 *
 * Swift side: Java_com_mn_android_data_StreakDetailSource_read in
 * KotlinStreakActivityStore.swift.
 */
object StreakDetailSource {

    init {
        Class.forName("com.mn.core.AIDraftMetric")
    }

    /**
     * Fills [medTimeMillis]/[noteTimeMillis] with epoch millis per day (-1 when
     * the day has no meditation / no note) and [statsOut] with
     * `[currentStreak, longestStreak, totalCompleteDays]`.
     */
    external fun read(
        dayStartMillis: LongArray,
        medTimeMillis: LongArray,
        noteTimeMillis: LongArray,
        statsOut: LongArray,
    )

    /** One day of the grid, `null` for the padding cells that fill a week. */
    data class Day(
        val date: LocalDate,
        val meditationTime: Long?,
        val noteTime: Long?,
    ) {
        val hasMeditation: Boolean get() = meditationTime != null
        val hasNote: Boolean get() = noteTime != null
        val isComplete: Boolean get() = hasMeditation && hasNote
    }

    data class Detail(
        val currentStreak: Int,
        val longestStreak: Int,
        val totalCompleteDays: Int,
        /** Week rows, Sunday first, `null` cells pad the first and last week. */
        val weeks: List<List<Day?>>,
    ) {
        val today: Day? get() = weeks.flatten().firstOrNull { it?.date == LocalDate.now() }
    }

    fun readDetail(anchor: LocalDate = LocalDate.now()): Detail {
        val zone = ZoneId.systemDefault()
        val monthStart = anchor.withDayOfMonth(1)
        // iOS calendar grid: gregorian, en_US, Sunday first, so the leading
        // offset is dayOfWeek with Sunday as 0. java.time is ISO (Monday = 1),
        // hence the % 7.
        val cells = ArrayList<Day?>(42)
        repeat(monthStart.dayOfWeek.value % 7) { cells.add(null) }
        repeat(monthStart.lengthOfMonth()) { cells.add(null) } // placeholders, filled below
        while (cells.size % 7 != 0) cells.add(null)

        val dates = (1..monthStart.lengthOfMonth()).map { monthStart.withDayOfMonth(it) }
        val offset = monthStart.dayOfWeek.value % 7
        val dayStarts = LongArray(dates.size)
        repeat(dates.size) { i ->
            dayStarts[i] = dates[i].atStartOfDay(zone).toInstant().toEpochMilli()
        }

        val med = LongArray(dates.size)
        val note = LongArray(dates.size)
        val stats = LongArray(3)
        read(dayStarts, med, note, stats)

        repeat(dates.size) { i ->
            cells[offset + i] = Day(
                date = dates[i],
                meditationTime = med[i].takeIf { it >= 0 },
                noteTime = note[i].takeIf { it >= 0 },
            )
        }

        return Detail(
            currentStreak = stats[0].toInt(),
            longestStreak = stats[1].toInt(),
            totalCompleteDays = stats[2].toInt(),
            weeks = cells.chunked(7),
        )
    }

    /** iOS `MMMM yyyy` in the en_US locale the iOS screen hardcodes. */
    fun monthTitle(anchor: LocalDate = LocalDate.now()): String =
        anchor.format(java.time.format.DateTimeFormatter.ofPattern("MMMM yyyy", java.util.Locale.US))
}
