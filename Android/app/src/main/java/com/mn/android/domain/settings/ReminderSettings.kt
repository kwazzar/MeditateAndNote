package com.mn.android.domain.settings

/**
 * When the daily reminder fires.
 *
 * The hour and minute are clamped by the rule that owns them (Swift's
 * `ReminderSettings.init`); this is the value the app reads and writes.
 */
data class ReminderSettings(
    val enabled: Boolean,
    val hour: Int,
    val minute: Int,
    /** Sunday = 1, matching Calendar. */
    val weekdays: Set<Int>,
) {
    companion object {
        /** Matches `ReminderSettings.defaultValue` in Swift. */
        val Default = ReminderSettings(
            enabled = false,
            hour = 20,
            minute = 0,
            weekdays = setOf(1, 2, 3, 4, 5, 6, 7),
        )
    }
}

/** Where the reminder settings live. */
interface ReminderSettingsStore {
    fun load(): ReminderSettings
    fun save(settings: ReminderSettings)
}
