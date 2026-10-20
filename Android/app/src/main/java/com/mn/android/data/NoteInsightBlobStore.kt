package com.mn.android.data

import android.content.Context

/**
 * Where the analyzed insights live.
 *
 * The document is written by Swift (the domain encodes it) and kept here as
 * opaque text — one JSON object per note id, keyed by that id. Kotlin never
 * parses an insight: it only hands the bytes back to the bridge, the same
 * split `AIDraftSessionStorage` uses for the draft sessions.
 *
 * An insight is small and there is one per note, so the preferences are
 * enough — no table, no schema, nothing to migrate.
 */
object NoteInsightBlobStore {

    private const val PREFS = "note_insights"
    private const val KEY_PREFIX = "insight_"

    private var context: Context? = null

    fun configure(context: Context) {
        this.context = context.applicationContext
    }

    @JvmStatic
    fun save(id: String, payload: String) {
        prefs()?.edit()?.putString(KEY_PREFIX + id, payload)?.apply()
    }

    /** The stored document, or "" when this note has no insight. */
    @JvmStatic
    fun load(id: String): String = prefs()?.getString(KEY_PREFIX + id, "") ?: ""

    @JvmStatic
    fun delete(id: String) {
        prefs()?.edit()?.remove(KEY_PREFIX + id)?.apply()
    }

    @JvmStatic
    fun deleteAll() {
        prefs()?.edit()?.clear()?.apply()
    }

    /**
     * Every payload as one JSON array.
     *
     * A single string rather than a list of strings: structured values do not
     * cross the JNI boundary. Concatenating the opaque payloads is still
     * valid JSON — every payload is a complete object and its separators are
     * untouched — so Swift decodes `[NoteInsight]` in one round trip.
     */
    @JvmStatic
    fun fetchAll(): String {
        val prefs = prefs() ?: return "[]"
        return buildString {
            append('[')
            var first = true
            for ((key, value) in prefs.all) {
                if (!key.startsWith(KEY_PREFIX) || value !is String) continue
                if (!first) append(',')
                first = false
                append(value)
            }
            append(']')
        }
    }

    private fun prefs() = context?.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
