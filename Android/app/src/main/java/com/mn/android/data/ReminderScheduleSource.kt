package com.mn.android.data

/**
 * Kotlin side of the reminder scheduling math.
 *
 * Swift runs the Core `ReminderScheduleBuilder` (one implementation, shared with
 * iOS) and fills the next fire dates into a buffer Kotlin allocated — the same
 * out-param rule the other data bridges use, because Swift cannot swap the
 * reference Kotlin passed.
 *
 * Swift side: `Java_com_mn_android_data_ReminderScheduleSource_fillNextFireDates`
 * in StreakInsightsBridge.swift.
 */
object ReminderScheduleSource {

    init {
        Class.forName("com.mn.core.ReminderScheduleBuilder")
    }

    /**
     * Fills [out] with the next fire dates (epoch millis) for the settings,
     * `-1` for the unused tail. Weekdays use Calendar's convention (1 = Sunday).
     */
    external fun fillNextFireDates(
        out: LongArray,
        enabled: Boolean,
        hour: Int,
        minute: Int,
        weekdays: LongArray,
        afterMillis: Long,
        tzOffsetMinutes: Int,
    )

    /** Returns the upcoming fire dates, `horizon` at most. */
    fun nextFireDates(
        enabled: Boolean,
        hour: Int,
        minute: Int,
        weekdays: Set<Int>,
        afterMillis: Long,
        horizon: Int = 7,
    ): List<Long> {
        val out = LongArray(horizon)
        // Swift-on-Android resolves TimeZone.current to UTC, so the device
        // offset travels explicitly — the same Calendar.current the iOS
        // builder gets for free.
        val tzOffsetMinutes = java.util.TimeZone.getDefault().getOffset(afterMillis) / 60_000
        fillNextFireDates(out, enabled, hour, minute, weekdays.map { it.toLong() }.toLongArray(), afterMillis, tzOffsetMinutes)
        return out.takeWhile { it >= 0 }
    }
}
