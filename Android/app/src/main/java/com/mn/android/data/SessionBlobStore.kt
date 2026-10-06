package com.mn.android.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * Completed meditation sessions stored as opaque blobs.
 *
 * Same shape and the same reasoning as `NoteBlobStore`: Room would be bought
 * for query power nothing asks for. What the Swift `MeditationSessionStore`
 * needs is one day-window range query ordered by completion time — SQLite does
 * that with two integer comparisons, and semantic search is not a session
 * concern at all.
 *
 * Kotlin never parses `payload`. Swift writes it, Swift reads it, the JSON
 * shape stays on the Swift side, so `MeditationSession` gains a field without
 * this file changing. `completedAt` is the one column Kotlin interprets,
 * because the range query has to run in SQL; it is derived from the payload
 * rather than stored independently, which is safe because `completedAt` is
 * immutable — `MeditationSession` exposes only `let` fields.
 *
 * `meditationId` is not a column: nothing filters on it, and it is already in
 * the payload.
 */
object SessionBlobStore {

    private const val DB_NAME = "sessions.db"
    private const val VERSION = 1
    private const val TABLE = "sessions"

    private const val ID = "id"
    private const val COMPLETED_AT = "completedAt"
    private const val PAYLOAD = "payload"

    private class SessionsDatabase(context: Context) :
        SQLiteOpenHelper(context, DB_NAME, null, VERSION) {

        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE $TABLE (
                    $ID TEXT PRIMARY KEY NOT NULL,
                    $COMPLETED_AT INTEGER NOT NULL,
                    $PAYLOAD TEXT NOT NULL
                )
                """.trimIndent()
            )
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            // Dropping would discard every session to gain an empty schema.
            // Version 1 has nowhere to migrate from, so an unexpected jump
            // fails loudly instead.
            error("no migration for $DB_NAME from v$oldVersion to v$newVersion")
        }
    }

    @Volatile
    private var database: SQLiteDatabase? = null

    fun configure(context: Context) {
        if (database == null) {
            synchronized(this) {
                if (database == null) {
                    database = SessionsDatabase(context).writableDatabase
                }
            }
        }
    }

    /** `INSERT OR REPLACE`: saving a known id replaces the row in place. */
    @JvmStatic
    fun save(id: String, completedAt: Long, payload: String) {
        val values = ContentValues().apply {
            put(ID, id)
            put(COMPLETED_AT, completedAt)
            put(PAYLOAD, payload)
        }
        requireNotNull(database)
            .insertWithOnConflict(TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    /**
     * Payloads with `completedAt` in `[start, end)`, newest first, as one JSON
     * array.
     *
     * Half-open to match the Swift side, which computes `start = startOfDay` and
     * `end = start + 1 day` and relies on the upper bound being excluded — the
     * same predicate `CoreDataSessionStore` writes.
     *
     * One string rather than a list of strings: structured values do not cross
     * the JNI boundary. Concatenating opaque payloads is still valid JSON
     * because the objects are complete and their separators are untouched.
     *
     * Passing `Long.MIN_VALUE`/`Long.MAX_VALUE` widens this to "every session",
     * which is how `allSessionDates()` reads without a second query method.
     */
    @JvmStatic
    fun fetch(start: Long, end: Long): String =
        requireNotNull(database).query(
            TABLE, arrayOf(PAYLOAD),
            "$COMPLETED_AT >= ? AND $COMPLETED_AT < ?",
            arrayOf(start.toString(), end.toString()),
            null, null,
            "$COMPLETED_AT DESC",
        ).use { cursor ->
            buildString {
                append('[')
                var first = true
                while (cursor.moveToNext()) {
                    if (!first) append(',')
                    first = false
                    append(cursor.getString(0))
                }
                append(']')
            }
        }

    @JvmStatic
    fun deleteAll() {
        requireNotNull(database).delete(TABLE, null, null)
    }
}
