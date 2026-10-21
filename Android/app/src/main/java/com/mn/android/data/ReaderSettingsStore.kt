package com.mn.android.data

import android.content.Context

/**
 * Reader appearance preferences (font size, paper theme).
 *
 * UI state, not domain state: the paper palette and the type size are
 * presentation choices, so they live in SharedPreferences instead of the
 * Core store. The iOS side keeps the same values in `ReaderSettings`.
 */
object ReaderSettingsStore {

    private const val PREFS = "reader_settings"
    private const val KEY_FONT_SIZE = "fontSize"
    private const val KEY_PAPER = "paper"

    @Volatile
    private var prefs: android.content.SharedPreferences? = null

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

    /** Font size in sp; defaults to the iOS default of 18. */
    fun fontSize(): Float {
        val stored = prefs?.getFloat(KEY_FONT_SIZE, 18f) ?: 18f
        return stored.coerceIn(12f, 32f)
    }

    fun setFontSize(size: Float) {
        prefs?.edit()?.putFloat(KEY_FONT_SIZE, size.coerceIn(12f, 32f))?.apply()
    }

    /** Paper theme name; one of "light", "sepia", "dark". */
    fun paper(): String {
        return prefs?.getString(KEY_PAPER, "sepia") ?: "sepia"
    }

    fun setPaper(name: String) {
        prefs?.edit()?.putString(KEY_PAPER, name)?.apply()
    }
}
