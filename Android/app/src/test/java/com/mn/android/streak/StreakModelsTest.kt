package com.mn.android.streak

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The domain rules the streak header and the month grid depend on. */
class StreakModelsTest {

    @Test fun todayIsCompleteOnlyWithBothActivities() {
        val complete = com.mn.android.domain.streak.Header(1, listOf(com.mn.android.domain.streak.DayFlags(true, true)))
        val meditationOnly = com.mn.android.domain.streak.Header(1, listOf(com.mn.android.domain.streak.DayFlags(true, false)))
        val noteOnly = com.mn.android.domain.streak.Header(1, listOf(com.mn.android.domain.streak.DayFlags(false, true)))
        val none = com.mn.android.domain.streak.Header(0, listOf(com.mn.android.domain.streak.DayFlags(false, false)))

        assertTrue(complete.isTodayComplete)
        assertFalse(meditationOnly.isTodayComplete)
        assertFalse(noteOnly.isTodayComplete)
        assertFalse(none.isTodayComplete)
    }

    @Test fun noteReminderOnlyAfterAMeditation() {
        val meditationOnly = com.mn.android.domain.streak.Header(1, listOf(com.mn.android.domain.streak.DayFlags(true, false)))
        val noteOnly = com.mn.android.domain.streak.Header(1, listOf(com.mn.android.domain.streak.DayFlags(false, true)))

        assertTrue(meditationOnly.showNoteReminder)
        assertFalse(noteOnly.showNoteReminder)
    }
}
