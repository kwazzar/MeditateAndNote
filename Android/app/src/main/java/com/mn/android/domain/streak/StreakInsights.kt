package com.mn.android.domain.streak

/**
 * The insight bundle the streak screen renders. Swift runs the same
 * `StreakInsightManager` the iOS screen uses, so the math stays in Core —
 * these types only carry what the bridge decoded.
 */
enum class Category { COMPLETION, PATTERN, TREND, RISK }

enum class RecommendationAction { NAVIGATE_TO_MEDITATION, NAVIGATE_TO_NOTE, SET_REMINDER }

data class HeatmapDay(
    val name: String,
    val shortName: String,
    val completionRate: Double,
    val totalDays: Int,
    val completeDays: Int,
    val breakRate: Double,
)

data class Heatmap(val days: List<HeatmapDay>)

data class Insight(
    val id: String,
    val category: Category,
    val title: String,
    val message: String,
    val value: Double?,
    val icon: String,
    val heatmap: Heatmap?,
)

data class Recommendation(
    val id: String,
    val priority: Int,
    val title: String,
    val message: String,
    val icon: String,
    val action: RecommendationAction?,
)

data class WeeklyBucket(
    val weekStartMillis: Long,
    val weekEndMillis: Long,
    val totalDays: Int,
    val completeDays: Int,
    val completionRate: Double,
)

data class DistributionBucket(val label: String, val count: Int)

data class Distribution(
    val buckets: List<DistributionBucket>,
    val totalStreaks: Int,
    val medianLength: Int,
)

data class SurvivalPoint(val day: Int, val probability: Double)

data class Resilience(
    val avgRecoveryDays: Double,
    val longestRecoveryDays: Int,
    val totalRecoveries: Int,
    val survival: List<SurvivalPoint>,
)

data class BreakPatternPoint(val weekday: Int, val rate: Double)

data class Bundle(
    val range: String,
    val insights: List<Insight>,
    val recommendations: List<Recommendation>,
    val weekly: List<WeeklyBucket>,
    val distribution: Distribution,
    val resilience: Resilience,
    val breakPattern: List<BreakPatternPoint>,
    val heatmap: Heatmap,
)
