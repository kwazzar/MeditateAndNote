package com.mn.android

import android.content.Context
import android.util.Log
import com.mn.android.data.NoteBlobStore

/**
 * Drives `KotlinNoteDataSource` through the whole blob round trip: Kotlin ->
 * Swift `JSONEncoder` -> Kotlin SQLite -> Swift `JSONDecoder` -> back to Kotlin.
 *
 * Driving it from Kotlin is what makes it a proof rather than a claim: a probe
 * living only on the Swift side would pass even if nothing ever reached Java.
 *
 * Results are counted rather than printed because print from Swift does not
 * reach logcat on this device.
 *
 * Swift side: KotlinNoteDataSource.swift
 */
object NoteProbe {

    private const val TAG = "NoteProbe"

    /** Matches `noteProbeSlots` in KotlinNoteDataSource.swift. */
    private const val SLOTS = 8

    private const val ROWS_AFTER_SAVE = 0
    private const val FETCH_ALL = 1
    private const val ORDER = 2
    private const val LOAD = 3
    private const val AFTER_DELETE = 4
    private const val AFTER_DELETE_ALL = 5
    private const val FAILED = 6

    fun roundTrip(context: Context): String {
        NoteBlobStore.configure(context)

        val results = LongArray(SLOTS)
        NativeProbe.noteProbe(results)
        return results.describe().also { Log.i(TAG, it) }
    }

    /**
     * A single verdict, so a green line cannot be mistaken for a partial one:
     * every slot has to hold what the probe expected for this to say PASS.
     */
    private fun LongArray.describe(): String {
        if (size < SLOTS) return "note probe malformed($size): ${joinToString(",")}"
        if (this[FAILED] != 0L) return "note probe threw before finishing"

        val passed = this[ROWS_AFTER_SAVE] == 2L &&
            this[FETCH_ALL] == 1L &&
            this[ORDER] == 1L &&
            this[LOAD] == 1L &&
            this[AFTER_DELETE] == 1L &&
            this[AFTER_DELETE_ALL] == 0L

        // Counts and flags are labelled differently on purpose: fetchAll=1
        // would otherwise read as "one row" when it means "the check passed".
        val detail = "save=${this[ROWS_AFTER_SAVE]} rows fetchAllOk=${this[FETCH_ALL] == 1L} " +
            "orderOk=${this[ORDER] == 1L} loadOk=${this[LOAD] == 1L} " +
            "afterDelete=${this[AFTER_DELETE]} rows afterDeleteAll=${this[AFTER_DELETE_ALL]} rows"
        return "note blob ${if (passed) "PASS" else "FAIL"}: $detail"
    }
}