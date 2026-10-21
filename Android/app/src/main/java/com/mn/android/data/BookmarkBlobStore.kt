package com.mn.android.data

import android.content.Context
import android.content.SharedPreferences

/**
 * Kotlin side of the Swift `BookmarkStore`: the reader's marks (page
 * bookmarks and passage highlights) as one JSON document.
 *
 * Same split as the other blob stores: Swift owns the bytes and the domain
 * shape, Kotlin owns the storage. One document for all books keeps deletion
 * simple — a mark id is enough to remove it, no book lookup needed.
 */
object BookmarkBlobStore {

    private const val PREFS = "bookmarks"
    private const val KEY = "marks"

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

    /** Replaces the whole document; Swift sends the updated array. */
    @JvmStatic
    fun save(json: String) {
        prefs?.edit()?.putString(KEY, json)?.apply()
    }

    /** Returns "" when nothing is stored. */
    @JvmStatic
    fun load(): String {
        return prefs?.getString(KEY, null).orEmpty()
    }

    @JvmStatic
    fun clear() {
        prefs?.edit()?.remove(KEY)?.apply()
    }
}
