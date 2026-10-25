package com.mn.android.data

import java.util.UUID
import org.json.JSONObject

/**
 * Kotlin side of the note editor's persistence calls.
 *
 * Swift normalises the title (trim, blank -> "Untitled") through the real
 * `NoteTitle` value object on save and hands the normalised value back, so
 * there is exactly one place that rule lives. `load` returns "" for an
 * unknown id — String? does not cross JNI, the same sentinel convention as
 * the other sources.
 *
 * Swift side: Java_com_mn_android_data_NoteEditorSource_* in
 * KotlinNoteDataSource.swift.
 */
object NoteEditorSource {

    init {
        // Editor can be the first JNI touch of the process (deep link from a
        // cold home back-stack restore), same force-load as NoteMenuSource.
        Class.forName("com.mn.core.AIDraftMetric")
    }

    /** "" = note not found. */
    external fun load(id: String): String

    /**
     * Returns the normalised title, "" on failure.
     *
     * The offset decides which calendar day the note fills in the streak:
     * Swift-on-Android resolves [java.util.TimeZone] to UTC (no tzdata), so
     * the JVM's own offset is passed down. Kept as a separate native method
     * name because a JVM overload of "save" would make the short JNI symbol
     * ambiguous.
     */
    external fun saveWithOffset(
        id: String,
        title: String,
        content: String,
        tzOffsetMinutes: Int,
    ): String

    /** [saveWithOffset] with the device's current UTC offset. */
    fun save(id: String, title: String, content: String): String =
        saveWithOffset(
            id,
            title,
            content,
            java.util.TimeZone.getDefault().getOffset(System.currentTimeMillis()) / 60_000,
        )

    external fun delete(id: String)

    data class EditorNote(
        val id: String,
        val title: String,
        val content: String,
        val dateMillis: Long,
    )

    /** New-note id, generated here so Kotlin owns navigation identity. */
    fun newId(): String = UUID.randomUUID().toString()

    fun loadNote(id: String): EditorNote? {
        val json = load(id)
        if (json.isEmpty()) return null
        val obj = JSONObject(json)
        return EditorNote(
            id = id,
            title = obj.getString("title"),
            content = obj.getString("content"),
            dateMillis = obj.getLong("dateMillis"),
        )
    }
}