package com.mn.android.infrastructure.persistence.local.meditation

import android.content.Context
import android.content.SharedPreferences

/**
 * Android side of Core's `MeditationSelectionStore`
 * (`MeditateAndNoteCore/Meditation/MeditationService.swift`): one optional
 * string under the same key, so both platforms read the same name side by side
 * while the storage stays per-platform (SharedPreferences here, UserDefaults
 * there) — the `OnboardingStore` arrangement. Not a JNI round trip for the same
 * reason: a last-picked id carries no invariant the domain can get wrong.
 */
object MeditationSelection {

    private const val PREFS = "meditation"
    private const val KEY = "lastSelectedMeditationId"

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

    var lastSelectedId: String?
        get() = prefs?.getString(KEY, null)
        set(value) {
            prefs?.edit()?.putString(KEY, value)?.apply()
        }
}
