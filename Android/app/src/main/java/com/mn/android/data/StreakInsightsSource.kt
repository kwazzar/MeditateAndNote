package com.mn.android.data

import org.json.JSONArray
import org.json.JSONObject

/**
 * Kotlin side of the streak-insights read.
 *
 * Swift runs `StreakInsightManager` (the same engine the iOS screen uses) and
 * returns one JSON document; this file only decodes it into the value objects
 * the Compose screen renders. The domain stays in Core — there is no Kotlin
 * reimplementation of the insight math to drift.
 *
 * Swift side: `Java_com_mn_android_data_StreakInsightsSource_read` in
 * StreakInsightsBridge.swift.
 */
object StreakInsightsSource {

    init {
        Class.forName("com.mn.core.StreakInsightManager")
    }

    external fun read(range: String): String

    // MARK: - Value objects

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

    // MARK: - Decoding

    fun load(range: String): Bundle {
        val root = JSONObject(read(range))
        return Bundle(
            range = root.getString("range"),
            insights = root.getJSONArray("insights").mapObjects { insight(it) },
            recommendations = root.getJSONArray("recommendations").mapObjects { recommendation(it) },
            weekly = root.getJSONArray("weekly").mapObjects { weeklyBucket(it) },
            distribution = distribution(root.getJSONObject("distribution")),
            resilience = resilience(root.getJSONObject("resilience")),
            breakPattern = root.getJSONArray("breakPattern").mapObjects {
                BreakPatternPoint(it.getInt("weekday"), it.getDouble("rate"))
            },
            heatmap = heatmap(root.getJSONObject("heatmap")),
        )
    }

    private fun insight(json: JSONObject) = Insight(
        id = json.getString("id"),
        category = when (json.getString("category")) {
            "completion" -> Category.COMPLETION
            "pattern" -> Category.PATTERN
            "trend" -> Category.TREND
            else -> Category.RISK
        },
        title = json.getString("title"),
        message = json.getString("message"),
        value = json.optDoubleOrNull("value"),
        icon = json.getString("icon"),
        heatmap = json.optJSONObject("heatmap")?.let { heatmap(it) },
    )

    private fun recommendation(json: JSONObject) = Recommendation(
        id = json.getString("id"),
        priority = json.getInt("priority"),
        title = json.getString("title"),
        message = json.getString("message"),
        icon = json.getString("icon"),
        action = when (json.optString("action", "")) {
            "navigateToMeditation" -> RecommendationAction.NAVIGATE_TO_MEDITATION
            "navigateToNote" -> RecommendationAction.NAVIGATE_TO_NOTE
            "setReminder" -> RecommendationAction.SET_REMINDER
            else -> null
        },
    )

    private fun weeklyBucket(json: JSONObject) = WeeklyBucket(
        weekStartMillis = json.getLong("weekStartMillis"),
        weekEndMillis = json.getLong("weekEndMillis"),
        totalDays = json.getInt("totalDays"),
        completeDays = json.getInt("completeDays"),
        completionRate = json.getDouble("completionRate"),
    )

    private fun distribution(json: JSONObject) = Distribution(
        buckets = json.getJSONArray("buckets").mapObjects {
            DistributionBucket(it.getString("label"), it.getInt("count"))
        },
        totalStreaks = json.getInt("totalStreaks"),
        medianLength = json.getInt("medianLength"),
    )

    private fun resilience(json: JSONObject) = Resilience(
        avgRecoveryDays = json.getDouble("avgRecoveryDays"),
        longestRecoveryDays = json.getInt("longestRecoveryDays"),
        totalRecoveries = json.getInt("totalRecoveries"),
        survival = json.getJSONArray("survival").mapObjects {
            SurvivalPoint(it.getInt("day"), it.getDouble("probability"))
        },
    )

    private fun heatmap(json: JSONObject) = Heatmap(
        days = json.getJSONArray("days").mapObjects {
            HeatmapDay(
                name = it.getString("name"),
                shortName = it.getString("shortName"),
                completionRate = it.getDouble("completionRate"),
                totalDays = it.getInt("totalDays"),
                completeDays = it.getInt("completeDays"),
                breakRate = it.getDouble("breakRate"),
            )
        },
    )

    private inline fun <T> JSONArray.mapObjects(transform: (JSONObject) -> T): List<T> =
        (0 until length()).map { transform(getJSONObject(it)) }

    /** `null` when the JSON value is JSON null; `optDouble` alone would read it as 0.0. */
    private fun JSONObject.optDoubleOrNull(key: String): Double? =
        if (isNull(key)) null else getDouble(key)
}
