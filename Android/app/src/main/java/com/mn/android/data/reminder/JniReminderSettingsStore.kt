package com.mn.android.data.reminder

import android.content.Context
import com.mn.android.data.SharedPrefsReminderSettingsStore
import com.mn.android.domain.settings.ReminderSettings
import com.mn.android.domain.settings.ReminderSettingsStore

/**
 * The reminder settings behind a domain value.
 *
 * The flat array is the JNI shape: Swift's `KotlinReminderSettingsStore` calls
 * `load`/`save` on the store itself, so those keep their signature. This
 * adapter is the app's way in — the value the screens read and write.
 */
class JniReminderSettingsStore(context: Context) : ReminderSettingsStore {

    private val store = SharedPrefsReminderSettingsStore

    init {
        // The receiver can run in a process the app never started: the
        // preferences have to be opened here, not at app startup.
        store.configure(context)
    }

    override fun load(): ReminderSettings {
        val raw = store.load()
        return ReminderSettings(
            enabled = raw.getOrElse(0) { 0L } == 1L,
            hour = raw.getOrElse(1) { 20L }.toInt(),
            minute = raw.getOrElse(2) { 0L }.toInt(),
            weekdays = raw.drop(3).map { it.toInt() }.toSet(),
        )
    }

    override fun save(settings: ReminderSettings) {
        store.save(
            enabled = settings.enabled,
            hour = settings.hour,
            minute = settings.minute,
            weekdays = settings.weekdays.sorted().map { it.toLong() }.toLongArray(),
        )
    }
}
