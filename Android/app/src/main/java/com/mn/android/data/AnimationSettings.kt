package com.mn.android.data

import android.content.Context
import android.content.SharedPreferences

/**
 * Android side of iOS `AnimationSettings`
 * (`Services/Settings/AnimationSettings.swift`): one persisted string under
 * the same key (`meditationAnimationStyle`), values `rings` / `path` — the
 * `BreathingAnimationStyle` raw values Core owns. Default `path`, like iOS.
 */
object AnimationSettings {

    private const val PREFS = "animationSettings"
    private const val KEY = "meditationAnimationStyle"

    const val RINGS = "rings"
    const val PATH = "path"

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

    var style: String
        get() = prefs?.getString(KEY, PATH)?.takeIf { it == RINGS || it == PATH } ?: PATH
        set(value) {
            prefs?.edit()?.putString(KEY, value)?.apply()
        }
}
