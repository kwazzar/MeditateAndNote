package com.mn.android.data

import android.content.Context
import android.content.SharedPreferences
import java.io.File

/**
 * Kotlin side of the Swift `BookStore` and of the book file storage.
 *
 * Same split as `StreakSnapshotStore`: Swift owns the bytes and the domain
 * logic (JSON encode/decode, upserts, position clamping), Kotlin owns dumb
 * key-value storage and file copying. Nothing here parses the documents.
 *
 * - `library` — one JSON array of book metas, read whole, rewritten on save.
 *   One key rather than one key per book: the library is always read whole and
 *   never queried by fields, so per-book keys would only complicate `loadAll`.
 * - `pos_<id>` / `cover_<id>` — per-book reading position JSON and cover base64.
 * - `importFile` copies a picked file into `filesDir/books/` and returns the
 *   stored path, which Swift reads directly (same process, same filesystem).
 *
 * "" means "nothing stored" because `String?` does not cross JNI.
 */
object BookBlobStore {

    private const val PREFS = "book_storage"
    private const val KEY_LIBRARY = "library"

    @Volatile
    private var prefs: SharedPreferences? = null

    @Volatile
    private var appContext: Context? = null

    fun configure(context: Context) {
        if (prefs == null) {
            synchronized(this) {
                if (prefs == null) {
                    appContext = context.applicationContext
                    prefs = context.applicationContext
                        .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                }
            }
        }
    }

    @JvmStatic
    fun saveLibrary(json: String) {
        prefs?.edit()?.putString(KEY_LIBRARY, json)?.apply()
    }

    @JvmStatic
    fun loadLibrary(): String {
        return prefs?.getString(KEY_LIBRARY, null).orEmpty()
    }

    @JvmStatic
    fun savePosition(id: String, json: String) {
        prefs?.edit()?.putString("pos_$id", json)?.apply()
    }

    @JvmStatic
    fun loadPosition(id: String): String {
        return prefs?.getString("pos_$id", null).orEmpty()
    }

    @JvmStatic
    fun saveCover(id: String, base64: String) {
        prefs?.edit()?.putString("cover_$id", base64)?.apply()
    }

    @JvmStatic
    fun loadCover(id: String): String {
        return prefs?.getString("cover_$id", null).orEmpty()
    }

    /** Removes the per-book keys; the library array itself is rewritten by Swift. */
    @JvmStatic
    fun clearBookData(id: String) {
        prefs?.edit()
            ?.remove("pos_$id")
            ?.remove("cover_$id")
            ?.apply()
    }

    /**
     * Copies [srcPath] into `filesDir/books/[fileName]` and returns the stored
     * absolute path, or "" when the copy failed.
     */
    @JvmStatic
    fun importFile(srcPath: String, fileName: String): String {
        return try {
            val context = appContext ?: return ""
            val dir = File(context.filesDir, "books")
            dir.mkdirs()
            val destination = File(dir, fileName)
            File(srcPath).copyTo(destination, overwrite = true)
            destination.absolutePath
        } catch (e: Exception) {
            ""
        }
    }

    @JvmStatic
    fun deleteFile(path: String) {
        try {
            File(path).delete()
        } catch (e: Exception) {
            // Best effort: a leftover file is invisible to the library.
        }
    }
}
