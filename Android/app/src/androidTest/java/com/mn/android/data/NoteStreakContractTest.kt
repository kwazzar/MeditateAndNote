package com.mn.android.data

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

/**
 * The streak half of the note/session contract, on the device.
 *
 * A day counts toward the streak only when it holds BOTH a meditation and a
 * note. Android has no DomainEventBus, so the streak is marked where the
 * activity happens: the session recorder on completion, the note save on
 * create. These tests are the guards for those two call sites — deleting
 * either inline mark fails a test here instead of silently shipping a streak
 * that never completes.
 *
 * The event-name rules are pinned too: only `.noteCreated` marks a day
 * (updates and deletes do not), and a day counts at most once.
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

    /**
     * Guards `SessionRecorder.record`'s inline streak mark. Without it a
     * completed meditation never fills its day, so a note written afterwards
     * can never complete the streak.
     */
    @Test
    fun recordingSession_fillsMeditationFlag_butDoesNotCompleteDay() {
        assertEquals(1L, SessionRecorder.record("probe-meditation", 60.0, tzOffsetMinutes))

        val header = StreakHeaderSource.readHeader()
        assertTrue("the completed session must fill today's meditation flag", header.today.hasMeditation)
        assertFalse("a meditation alone is a partial day", header.today.hasNote)
        assertFalse("a meditation alone does not complete the day", header.isTodayComplete)
        assertEquals("a partial day does not add to the streak", 0, header.currentStreak)
    }

    /**
     * Guards `NoteEditorSource.saveWithOffset`'s inline streak mark. Without
     * it a note never fills its day, the mirror image of the session test.
     */
    @Test
    fun savingNote_fillsNoteFlag_butDoesNotCompleteDay() {
        val id = UUID.randomUUID().toString()
        assertTrue(NoteEditorSource.save(id, "Morning note", "sunrise").isNotEmpty())

        val header = StreakHeaderSource.readHeader()
        assertTrue("the written note must fill today's note flag", header.today.hasNote)
        assertFalse("a note alone is a partial day", header.today.hasMeditation)
        assertFalse("a note alone does not complete the day", header.isTodayComplete)
        assertEquals("a partial day does not add to the streak", 0, header.currentStreak)
    }

    /**
     * iOS `.noteUpdated` breaks in `StreakTracker.handle` on purpose: only a
     * created note fills a day. The Android save path has the same rule
     * (`existing == nil`); this fails if saving an existing note starts
     * re-marking the day.
     */
    @Test
    fun updatingExistingNote_doesNotMarkDay() {
        val id = UUID.randomUUID().toString()
        assertTrue(NoteEditorSource.save(id, "Draft", "first").isNotEmpty())

        // Drop the mark the create produced, so a re-mark is visible.
        StreakSnapshotStore.save("")

        assertTrue(NoteEditorSource.save(id, "Draft", "edited").isNotEmpty())

        val header = StreakHeaderSource.readHeader()
        assertFalse("updating an existing note must not fill a day", header.today.hasNote)
        assertEquals(0, header.currentStreak)
    }

    /**
     * iOS `.noteDeleted` breaks in `StreakTracker.handle`: deleting a note
     * does not take back the day it filled. Guards the delete JNI entry from
     * growing an "unmark" side effect.
     */
    @Test
    fun deletingNote_keepsTheDayItFilled() {
        assertEquals(1L, SessionRecorder.record("probe-meditation", 60.0, tzOffsetMinutes))
        val id = UUID.randomUUID().toString()
        assertTrue(NoteEditorSource.save(id, "Evening note", "calm").isNotEmpty())

        NoteEditorSource.delete(id)

        val header = StreakHeaderSource.readHeader()
        assertTrue("deleting a note must not clear its day", header.today.hasNote)
        assertTrue(header.isTodayComplete)
        assertEquals(1, header.currentStreak)
    }

    /** A day counts at most once, no matter how many sessions it holds. */
    @Test
    fun secondSessionOnCompletedDay_doesNotInflateStreak() {
        assertEquals(1L, SessionRecorder.record("probe-meditation-1", 60.0, tzOffsetMinutes))
        val id = UUID.randomUUID().toString()
        assertTrue(NoteEditorSource.save(id, "Evening note", "calm").isNotEmpty())
        assertEquals(1, StreakHeaderSource.readHeader().currentStreak)

        assertEquals(1L, SessionRecorder.record("probe-meditation-2", 60.0, tzOffsetMinutes))

        val header = StreakHeaderSource.readHeader()
        assertEquals("a second session must not add a streak day", 1, header.currentStreak)
        assertEquals(1, header.dayFlags.count { it.hasMeditation })
    }
}
