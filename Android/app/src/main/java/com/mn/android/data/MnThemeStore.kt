package com.mn.android.data

import android.content.Context
import android.content.SharedPreferences
import com.mn.android.ui.theme.MainTheme

/**
 * Android side of the Swift `ThemeManager` storage
 * (`MeditateAndNote/Services/Theme/ThemeManager.swift`): one theme key.
 *
 * Key `selectedMainTheme` matches the Swift `storageKey` so the two platforms
 * stay readable side by side; storage is per-platform (SharedPreferences here,
 * UserDefaults there), nothing shared.
 */
object MnThemeStore {

    private const val PREFS = "theme"
    private const val KEY = "selectedMainTheme"

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

    var selected: MainTheme
        get() = MainTheme.fromStorageKey(prefs?.getString(KEY, null))
        set(value) {
            prefs?.edit()?.putString(KEY, value.storageKey)?.apply()
        }
}
