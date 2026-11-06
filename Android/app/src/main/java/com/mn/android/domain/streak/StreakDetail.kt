package com.mn.android.domain.streak

import java.time.LocalDate

/** One day of the month grid: the activity times, `null` when there is none. */
data class Day(
    val date: LocalDate,
    val meditationTime: Long?,
    val noteTime: Long?,
) {
    val hasMeditation: Boolean get() = meditationTime != null
    val hasNote: Boolean get() = noteTime != null
    val isComplete: Boolean get() = hasMeditation && hasNote
}

/**
 * The streak stats header plus the current-month calendar.
 */
data class Detail(
    val currentStreak: Int,
    val longestStreak: Int,
    val totalCompleteDays: Int,
    /** Week rows, Sunday first, `null` cells pad the first and last week. */
    val weeks: List<List<Day?>>,
) {
    val today: Day? get() = weeks.flatten().firstOrNull { it?.date == LocalDate.now() }
}
