package com.mn.android.domain.settings

/** Arms the next reminder dates after the settings changed. */
interface ReminderScheduler {
    fun reschedule()
}
