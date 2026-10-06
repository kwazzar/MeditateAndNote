package com.mn.android.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * Notes stored as an opaque blob.
 *
 * Room is not used, and the reason is the query surface rather than habit: the
 * Swift `NoteDataSource` only ever asks for all notes ordered by date, one note
 * by id, save, delete. `CoreDataNoteDataSource` matches — its only predicates are
 * `id == %@`, and keyword/semantic search runs in memory over `[Note]` in
 * `SemanticSearchManager`, never in SQL. Room exists for query power we would
 * not spend.
 *
 * Kotlin never parses `payload`. It is text: Swift writes it, Swift reads it,
 * the JSON shape stays on the Swift side of the boundary. That keeps the schema
 * from becoming a second declaration of `Note` — the drift problem the plan
 * warns about — and it is what `SharedPrefsReminderSettingsStore` already does
 * with the weekday array.
 *
 * `date` is the one column Kotlin does interpret, because `ORDER BY` has to
 * happen in the database. It is derived from the payload rather than stored
 * independently, which is safe only because `Note.date` is immutable:
 * `updating(content:)` and `retitle(_:)` both copy it unchanged.
 *
 * Context is injected once via `configure`, same as the reminder store, so the
 * JNI signatures stay primitives and strings.
 */
object NoteBlobStore {

    private const val DB_NAME = "notes.db"
    private const val VERSION = 1
    private const val TABLE = "notes"

    private const val ID = "id"
    private const val DATE = "date"
    private const val PAYLOAD = "payload"

    private class NotesDatabase(context: Context) :
        SQLiteOpenHelper(context, DB_NAME, null, VERSION) {

        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE $TABLE (
                    $ID TEXT PRIMARY KEY NOT NULL,
                    $DATE INTEGER NOT NULL,
                    $PAYLOAD TEXT NOT NULL
                )
                """.trimIndent()
            )
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            // Dropping the table would discard every note to gain an empty
            // schema. Version 1 has nowhere to migrate from, so an unexpected
            // jump fails loudly instead.
            error("no migration for $DB_NAME from v$oldVersion to v$newVersion")
        }
    }

    @Volatile
    private var database: SQLiteDatabase? = null

    fun configure(context: Context) {
        if (database == null) {
            synchronized(this) {
                if (database == null) {
                    database = NotesDatabase(context).writableDatabase
                }
            }
        }
    }

    /** `INSERT OR REPLACE`: saving a known id overwrites the row in place. */
    @JvmStatic
    fun save(id: String, date: Long, payload: String) {
        val values = ContentValues().apply {
            put(ID, id)
            put(DATE, date)
            put(PAYLOAD, payload)
        }
        requireNotNull(database)
            .insertWithOnConflict(TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    /**
     * Raw payload for one id, or "" when nothing is stored under it.
     *
     * Empty rather than null because `Optional<String>` does not conform to
     * JavaValue on the Swift side, so null could not arrive as `String?.self`.
     * A note payload always encodes a JSON object and is never empty, so "" is
     * unambiguous.
     */
    @JvmStatic
    fun load(id: String): String =
        requireNotNull(database).query(
            TABLE, arrayOf(PAYLOAD),
            "$ID = ?", arrayOf(id),
            null, null, null,
        ).use { if (it.moveToFirst()) it.getString(0) else "" }

    /**
     * Every payload in `date` order, newest first, as one JSON array.
     *
     * A single string rather than a list of strings: structured values do not
     * cross the JNI boundary (a SwiftSet already refused to). Concatenating the
     * opaque payloads is still valid JSON — the objects are complete and their
     * separators are untouched — so Swift decodes `[Note]` in one round trip.
     */
    @JvmStatic
    fun fetchAll(): String =
        requireNotNull(database).query(
            TABLE, arrayOf(PAYLOAD),
            null, null, null, null,
            "$DATE DESC",
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
    fun delete(id: String) {
        requireNotNull(database).delete(TABLE, "$ID = ?", arrayOf(id))
    }

    @JvmStatic
    fun deleteAll() {
        requireNotNull(database).delete(TABLE, null, null)
    }
}