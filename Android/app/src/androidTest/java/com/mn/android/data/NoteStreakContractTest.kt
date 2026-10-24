package com.mn.android.data

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

/**
 * The note half of the streak invariant, on the device.
 *
 * A day counts toward the streak only when it holds BOTH a meditation and a
 * note. Android has no DomainEventBus, so the note save is where the note and
 * the streak meet — without that mark the note never filled the day and the
 * streak could never complete.
 */
@RunWith(AndroidJUnit4::class)
class NoteStreakContractTest {

    private val tzOffsetMinutes: Int
        get() = java.util.TimeZone.getDefault().getOffset(System.currentTimeMillis()) / 60_000

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        // The stores are configured by MainActivity, which never runs in a
        // test — configure the three this path touches.
        StreakSnapshotStore.configure(context)
        SessionBlobStore.configure(context)
        NoteBlobStore.configure(context)
        StreakSnapshotStore.save("")
    }

    @Test
    fun savingNote_fillsStreakDay_soMeditationAndNoteCount() {
        assertEquals(1L, SessionRecorder.record("probe-meditation", 60.0, tzOffsetMinutes))

        val id = UUID.randomUUID().toString()
        assertTrue(NoteEditorSource.save(id, "Evening note", "calm breathing practice").isNotEmpty())

        val header = StreakHeaderSource.readHeader()
        assertTrue("the written note must fill today's note flag", header.today.hasNote)
        assertTrue("today must be complete: meditation + note", header.isTodayComplete)
        assertEquals(1, header.currentStreak)
    }
}
