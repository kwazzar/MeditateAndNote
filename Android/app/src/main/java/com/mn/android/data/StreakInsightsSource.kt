package com.mn.android.data

import com.mn.android.domain.streak.BreakPatternPoint
import com.mn.android.domain.streak.Bundle
import com.mn.android.domain.streak.Category
import com.mn.android.domain.streak.Distribution
import com.mn.android.domain.streak.DistributionBucket
import com.mn.android.domain.streak.Heatmap
import com.mn.android.domain.streak.HeatmapDay
import com.mn.android.domain.streak.Insight
import com.mn.android.domain.streak.Recommendation
import com.mn.android.domain.streak.RecommendationAction
import com.mn.android.domain.streak.Resilience
import com.mn.android.domain.streak.SurvivalPoint
import com.mn.android.domain.streak.WeeklyBucket
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
