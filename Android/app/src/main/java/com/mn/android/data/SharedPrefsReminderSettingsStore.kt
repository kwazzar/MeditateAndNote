package com.mn.android.data

import android.content.Context
import android.content.SharedPreferences

/**
 * Kotlin implementation of the Swift `ReminderSettingsStore` protocol.
 *
 * SharedPreferences rather than Room: this is a single small settings blob, and
 * Room's cost only pays off once rows are queried or migrated. Matches the
 * UserDefaults -> SharedPreferences mapping in ANDROID_PORT_PLAN.md.
 *
 * The API is deliberately flat — primitives and a LongArray, no Swift types.
 * Kotlin cannot hand back a Swift `ReminderSettings` without owning an arena on
 * the other side of the boundary, and the alternative (exposing the struct)
 * would put the hour/minute clamping invariant in two places. Flat means the
 * invariant stays in `ReminderSettings.init` where it belongs, and Kotlin's job
 * stops at storing four values.
 *
 * Context is injected once via `configure` rather than passed per call, so the
 * JNI signatures stay argument-free or primitive. Swift's
 * `KotlinReminderSettingsStore` calls straight into these.
 */
object SharedPrefsReminderSettingsStore {

    private const val PREFS = "reminder_settings"
    private const val KEY_ENABLED = "isEnabled"
    private const val KEY_HOUR = "hour"
    private const val KEY_MINUTE = "minute"
    private const val KEY_WEEKDAYS = "weekdays"

    /** Matches `ReminderSettings.defaultValue` in Swift. */
    private const val DEFAULT_HOUR = 20L
    private const val DEFAULT_MINUTE = 0L
    private val DEFAULT_WEEKDAYS = longArrayOf(1, 2, 3, 4, 5, 6, 7)

    @Volatile
    private var prefs: SharedPreferences? = null

    fun configure(context: Context) {
        if (prefs == null) {
            synchronized(this) {
                if (prefs == null) {
                    prefs = context.applicationContext
                        .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                }
            }
        }
    }

    /**
     * Returns [enabled, hour, minute, ...weekdays] as one array.
     *
     * A single array instead of four separate calls because every JNI crossing
     * costs, and the Swift side would otherwise need three round trips to learn
     * nothing changed. Sunday = 1, matching Calendar's convention.
     */
    @JvmStatic
    fun load(): LongArray {
        val store = prefs
            ?: return longArrayOf(0L, DEFAULT_HOUR, DEFAULT_MINUTE) + DEFAULT_WEEKDAYS
        val weekdays = store.getStringSet(KEY_WEEKDAYS, null)
            ?.mapNotNull { it.toIntOrNull() }
            ?.sorted()
            ?: DEFAULT_WEEKDAYS.toList()
        return longArrayOf(
            if (store.getBoolean(KEY_ENABLED, false)) 1L else 0L,
            store.getInt(KEY_HOUR, DEFAULT_HOUR.toInt()).toLong(),
            store.getInt(KEY_MINUTE, DEFAULT_MINUTE.toInt()).toLong(),
        ) + weekdays.map { it.toLong() }.toLongArray()
    }

    /**
     * Weekdays are stored as a StringSet because that is what
     * SharedPreferences supports natively. String because Int has no
     * StringSet overload and encoding into one string would be a format we then
     * have to migrate later.
     */
    @JvmStatic
    fun save(enabled: Boolean, hour: Int, minute: Int, weekdays: LongArray) {
        prefs?.edit()
            ?.putBoolean(KEY_ENABLED, enabled)
            ?.putInt(KEY_HOUR, hour)
            ?.putInt(KEY_MINUTE, minute)
            ?.putStringSet(KEY_WEEKDAYS, weekdays.map { it.toString() }.toSet())
            ?.apply()
    }
}