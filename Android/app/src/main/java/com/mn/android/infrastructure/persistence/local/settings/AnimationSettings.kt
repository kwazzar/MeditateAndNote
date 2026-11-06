package com.mn.android.infrastructure.persistence.local.settings

import android.content.Context
import android.content.SharedPreferences
import com.mn.android.domain.settings.AnimationStyle
import com.mn.android.domain.settings.AnimationStyleStore

/**
 * Android side of iOS `AnimationSettings`
 * (`Services/Settings/AnimationSettings.swift`): one persisted string under
 * the same key (`meditationAnimationStyle`), values `rings` / `path` — the
 * `BreathingAnimationStyle` raw values Core owns. Default `path`, like iOS.
 */
object AnimationSettings : AnimationStyleStore {

    private const val PREFS = "animationSettings"
    private const val KEY = "meditationAnimationStyle"

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

    override var style: AnimationStyle
        get() = AnimationStyle.of(prefs?.getString(KEY, null))
        set(value) {
            prefs?.edit()?.putString(KEY, value.raw)?.apply()
        }
}
