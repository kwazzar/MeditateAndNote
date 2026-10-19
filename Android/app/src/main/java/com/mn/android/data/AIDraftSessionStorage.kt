package com.mn.android.data

import android.content.Context
import org.json.JSONObject

/**
 * Where the AI draft sessions live.
 *
 * The session document is written by Swift (the domain encodes it) and kept
 * here as an opaque string — Kotlin never parses a session, it only hands the
 * document back to the bridge. One document per note, like iOS: a new draft
 * replaces the previous one for that note.
 */
object AIDraftSessionStorage {

    private const val PREFS = "ai_draft_sessions"
    private const val KEY_PREFIX = "session_"

    private var context: Context? = null

    fun configure(context: Context) {
        this.context = context.applicationContext
    }

    /** The stored document, or "" when the note has no session. */
    @JvmStatic
    fun load(noteId: String): String = prefs()?.getString(KEY_PREFIX + noteId, "") ?: ""

    @JvmStatic
    fun save(noteId: String, document: String) {
        prefs()?.edit()?.putString(KEY_PREFIX + noteId, document)?.apply()
    }

    @JvmStatic
    fun delete(noteId: String) {
        prefs()?.edit()?.remove(KEY_PREFIX + noteId)?.apply()
    }

    /** Every stored document, keyed by note id: `{"<noteId>": "<document>"}`. */
    @JvmStatic
    fun all(): String {
        val prefs = prefs() ?: return "{}"
        val result = JSONObject()
        for ((key, value) in prefs.all) {
            if (key.startsWith(KEY_PREFIX) && value is String) {
                result.put(key.removePrefix(KEY_PREFIX), value)
            }
        }
        return result.toString()
    }

    @JvmStatic
    fun deleteAll() {
        prefs()?.edit()?.clear()?.apply()
    }

    private fun prefs() = context?.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
