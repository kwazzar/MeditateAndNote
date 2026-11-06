package com.mn.android.domain.streak

/**
 * What a day of the streak window holds: did the user meditate, did they
 * write a note. Both together make the day complete.
 */
data class DayFlags(val hasMeditation: Boolean, val hasNote: Boolean)

/**
 * The home tab's streak snapshot: the current streak plus one [DayFlags] per
 * day of the last-seven-day window, oldest first.
 */
data class Header(
    val currentStreak: Int,
    val dayFlags: List<DayFlags>,
) {
    val today: DayFlags get() = dayFlags.lastOrNull() ?: DayFlags(false, false)
    val isTodayComplete: Boolean get() = today.hasMeditation && today.hasNote
    val showNoteReminder: Boolean get() = today.hasMeditation && !today.hasNote
}
