package com.mn.android.infrastructure.persistence.local.settings

import android.content.Context
import android.content.SharedPreferences
import com.mn.android.domain.settings.SoundVolumeStore

/**
 * Android side of iOS `SoundSettings` (`Services/Sound/SoundSettings.swift`):
 * one persisted Float under the same key (`meditationSoundVolume`), clamped
 * to 0...1, default 0.2. Storage stays per-platform (SharedPreferences vs
 * UserDefaults) — the `MeditationSelection` arrangement.
 */
object SoundSettings : SoundVolumeStore {

    private const val PREFS = "soundSettings"
    private const val KEY = "meditationSoundVolume"

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

    override var volume: Float
        get() = (prefs?.getFloat(KEY, 0.2f) ?: 0.2f).coerceIn(0f, 1f)
        set(value) {
            prefs?.edit()?.putFloat(KEY, value.coerceIn(0f, 1f))?.apply()
        }
}
