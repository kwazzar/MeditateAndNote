package com.mn.android.data

import org.json.JSONArray
import org.json.JSONObject

/**
 * Kotlin side of the notes list read.
 *
 * Swift decodes the stored note payloads — Kotlin only ever sees the flat
 * records this source hands over. The wire format is defined in
 * `Java_com_mn_android_data_NoteMenuSource_read` (KotlinNoteDataSource.swift),
 * not by the Core schema: [[0]=count, [1+i]=date millis] in [out] and a JSON
 * array of {"id","title","content"} as the return value.
 *
 * Search is a local case-insensitive contains over title/content, mirroring
 * `NoteFilter.matches`. The real NoteFilter needs generated `Note` objects
 * (arena machinery per row); the Core rule is about not re-declaring the Note
 * schema, and this mirror uses only the two already-handed-over fields.
 */
object NoteMenuSource {

    init {
        // Same forced .so load as StreakHeaderSource: the notes tab can be the
        // first JNI touch of the process.
        Class.forName("com.mn.core.AIDraftMetric")
    }

    /** Fills [out] with [count, dateMillis per note...], returns the records JSON. */
    external fun read(out: LongArray): String

    data class NoteRecord(
        val id: String,
        val title: String,
        val content: String,
        val dateMillis: Long,
    )

    data class NoteMenuData(val notes: List<NoteRecord>)

    fun readMenu(): NoteMenuData {
        // Hard cap, mirrored by the capacity check in the Swift thunk: the
        // buffer is sized before the count is known, so an overrun flips
        // [0] to -1 instead of truncating silently.
        val out = LongArray(1024)
        val json = read(out)
        val count = out[0].toInt()
        require(count >= 0) { "note count ($count) does not fit the 1023-note buffer" }
        val array = JSONArray(json)
        val notes = ArrayList<NoteRecord>(count)
        for (i in 0 until count) {
            val obj = array.getJSONObject(i)
            notes += NoteRecord(
                id = obj.getString("id"),
                title = obj.getString("title"),
                content = obj.getString("content"),
                dateMillis = out[1 + i],
            )
        }
        return NoteMenuData(notes)
    }
}