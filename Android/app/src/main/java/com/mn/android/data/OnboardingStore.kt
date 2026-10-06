package com.mn.android.data

import android.content.Context
import android.content.SharedPreferences

/**
 * Android side of the Swift `OnboardingStore` contract
 * (`MeditateAndNoteCore/Onboarding/OnboardingStore.swift`): one boolean.
 *
 * Deliberately not a JNI round trip. The flag is read on the cold-start path to
 * pick the NavHost's start destination, before any Swift code runs, and the
 * value has no invariant behind it — "already finished" is not something the
 * domain can get wrong. Shipping a boolean to Swift and back would add a
 * failure mode to app launch and buy nothing.
 *
 * The key matches `UserDefaultsOnboardingStore.storageKey` so the two platforms
 * stay readable side by side, but the storage is per-platform: SharedPreferences
 * here, UserDefaults there, nothing shared.
 */
object OnboardingStore {

    private const val PREFS = "onboarding"
    private const val KEY = "hasCompletedOnboarding"

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

    var hasCompletedOnboarding: Boolean
        get() = prefs?.getBoolean(KEY, false) ?: false
        set(value) {
            prefs?.edit()?.putBoolean(KEY, value)?.apply()
        }
}
