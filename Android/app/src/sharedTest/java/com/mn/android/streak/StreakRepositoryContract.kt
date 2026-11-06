package com.mn.android.streak

import com.mn.android.domain.streak.StreakRepository
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The shape every StreakRepository implementation has to keep, whatever backs
 * it. The assertions are on the structure the screens render, not on the
 * numbers a specific store happens to hold.
 */
abstract class StreakRepositoryContract {
    protected abstract fun createRepo(): StreakRepository

    @Test fun headerCoversSevenDays() {
        val header = createRepo().readHeader()
        assertEquals(7, header.dayFlags.size)
        assertTrue(header.currentStreak >= 0)
    }

    @Test fun detailWeeksAreSevenWide() {
        val detail = createRepo().readDetail()
        assertTrue(detail.weeks.isNotEmpty())
        assertTrue(detail.weeks.all { it.size == 7 })
    }

    @Test fun insightsCarryTheirRange() {
        val bundle = createRepo().readInsights("last7")
        assertTrue(bundle.range.isNotEmpty())
    }
}
