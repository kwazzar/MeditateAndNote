package com.mn.android.data

import android.content.Context
import android.content.SharedPreferences

/**
 * Kotlin side of the Swift `StreakActivityStore`: one JSON document in
 * SharedPreferences, stored and returned as opaque text.
 *
 * Same split as `NoteBlobStore`: Swift owns the bytes, Kotlin owns the storage.
 * `StreakSnapshot` is Codable in the domain package, so its shape exists in
 * exactly one place — this file never parses it, which is why there is no Kotlin
 * mirror to drift when the snapshot gains a field.
 *
 * SharedPreferences rather than Room: there is one row, always read whole,
 * never queried or joined. Room would be bought for a single key.
 *
 * "" means "nothing stored" because `String?` does not cross JNI — the same
 * sentinel `NoteBlobStore.load` uses. A snapshot always encodes as a non-empty
 * JSON object, so a real value can never collide with it.
 *
 * Context is injected once via `configure`, matching the other two stores, so
 * the JNI signatures stay string-only.
 */
object StreakSnapshotStore {

    private const val PREFS = "streak_snapshot"
    private const val KEY = "snapshot"

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

    /** Replaces whatever was stored; the protocol has no append operation. */
    @JvmStatic
    fun save(json: String) {
        prefs?.edit()?.putString(KEY, json)?.apply()
    }

    /** Returns "" when nothing valid is stored, never a partial document. */
    @JvmStatic
    fun load(): String {
        return prefs?.getString(KEY, null).orEmpty()
    }
}
