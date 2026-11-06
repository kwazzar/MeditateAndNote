package com.mn.android.streak

import com.mn.android.domain.streak.BreakPatternPoint
import com.mn.android.domain.streak.Bundle
import com.mn.android.domain.streak.Category
import com.mn.android.domain.streak.Day
import com.mn.android.domain.streak.DayFlags
import com.mn.android.domain.streak.Detail
import com.mn.android.domain.streak.Distribution
import com.mn.android.domain.streak.DistributionBucket
import com.mn.android.domain.streak.Header
import com.mn.android.domain.streak.Heatmap
import com.mn.android.domain.streak.HeatmapDay
import com.mn.android.domain.streak.Insight
import com.mn.android.domain.streak.Recommendation
import com.mn.android.domain.streak.Resilience
import com.mn.android.domain.streak.StreakRepository
import com.mn.android.domain.streak.WeeklyBucket
import java.time.LocalDate

class FakeStreakRepository(
    private val today: LocalDate = LocalDate.now(),
) : StreakRepository {

    override fun readHeader(): Header = Header(
        currentStreak = 4,
        dayFlags = List(7) { DayFlags(hasMeditation = it % 2 == 0, hasNote = it % 3 == 0) },
    )

    override fun readDetail(anchor: LocalDate): Detail = Detail(
        currentStreak = 4,
        longestStreak = 12,
        totalCompleteDays = 40,
        weeks = List(6) { week ->
            List(7) { day ->
                val date = anchor.withDayOfMonth(1).plusDays((week * 7 + day).toLong())
                Day(date, meditationTime = 1_000L, noteTime = 2_000L)
            }
        },
    )

    override fun readInsights(range: String): Bundle = Bundle(
        range = range,
        insights = listOf(
            Insight(
                id = "fake-insight",
                category = Category.COMPLETION,
                title = "Fake insight",
                message = "A fake insight for the tests.",
                value = 0.5,
                icon = "chart",
                heatmap = null,
            )
        ),
        recommendations = listOf(
            Recommendation(
                id = "fake-recommendation",
                priority = 1,
                title = "Fake recommendation",
                message = "A fake recommendation for the tests.",
                icon = "bell",
                action = null,
            )
        ),
        weekly = listOf(
            WeeklyBucket(0L, 0L, totalDays = 7, completeDays = 3, completionRate = 0.4)
        ),
        distribution = Distribution(
            buckets = listOf(DistributionBucket("1-2", 2)),
            totalStreaks = 4,
            medianLength = 2,
        ),
        resilience = Resilience(
            avgRecoveryDays = 1.5,
            longestRecoveryDays = 3,
            totalRecoveries = 2,
            survival = emptyList(),
        ),
        breakPattern = listOf(BreakPatternPoint(1, 0.2)),
        heatmap = Heatmap(
            days = listOf(
                HeatmapDay("Monday", "Mo", 0.4, totalDays = 7, completeDays = 3, breakRate = 0.1)
            )
        ),
    )
}
