package com.mn.android.infrastructure.persistence.local.settings

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

    /**
     * `BreathingAnimationStyle.isPremium` on iOS: `path` is the free default,
     * `rings` needs the `pro` entitlement.
     *
     * The rule itself lives in Core (`BreathingAnimationStyle.swift`), but
     * jextract does not generate a getter for a computed property of an enum,
     * so the value is mirrored here. Keep it in sync with Core.
     */
    fun isPremium(style: String): Boolean = style == RINGS
}
