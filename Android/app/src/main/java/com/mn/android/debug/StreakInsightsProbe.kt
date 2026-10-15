package com.mn.android.debug

import android.content.Context
import android.util.Log
import com.mn.android.data.StreakInsightsSource
import com.mn.android.data.StreakSnapshotStore

/**
 * Drives the streak-insights read end to end: Swift writes a known snapshot,
 * then runs every `StreakInsightManager` metric the detail screen renders, and
 * Kotlin decodes the real bundle the screen will consume.
 *
 * Proves the newest JNI symbol, the insight bundle crossing back intact, and the
 * Kotlin JSON decode of it.
 *
 * Swift side: `streakInsightsProbe` in StreakInsightsBridge.swift
 */
object StreakInsightsProbe {

    private const val TAG = "StreakInsightsProbe"

    private const val SLOTS = 8

    private const val INSIGHTS = 0
    private const val RECOMMENDATIONS = 1
    private const val WEEKLY = 2
    private const val DISTRIBUTION = 3
    private const val RESILIENCE = 4
    private const val HEATMAP = 5
    private const val FAILED = 6
    private const val DECODE = 7

    fun roundTrip(context: Context): String {
        StreakSnapshotStore.configure(context)

        val results = LongArray(SLOTS)
        NativeProbe.streakInsightsProbe(results)
        if (results[FAILED] == 0L) {
            results[DECODE] = runCatching {
                val bundle = StreakInsightsSource.load("last7")
                if (bundle.range == "last7" && bundle.insights.isNotEmpty() &&
                    bundle.recommendations.isNotEmpty() && bundle.heatmap.days.size == 7 &&
                    bundle.distribution.buckets.isNotEmpty()
                ) 1L else 0L
            }.getOrElse {
                Log.w(TAG, "decode failed: ${it.javaClass.simpleName}: ${it.message}")
                0L
            }
        }
        return results.describe().also { Log.i(TAG, it) }
    }

    private fun LongArray.describe(): String {
        if (size < SLOTS) return "streak insights probe malformed($size): ${joinToString(",")}"
        if (this[FAILED] != 0L) return "streak insights probe threw before finishing"

        val checks = mapOf(
            "insightsOk" to (this[INSIGHTS] == 1L),
            "recommendationsOk" to (this[RECOMMENDATIONS] == 1L),
            "weeklyOk" to (this[WEEKLY] == 1L),
            "distributionOk" to (this[DISTRIBUTION] == 1L),
            "resilienceOk" to (this[RESILIENCE] == 1L),
            "heatmapOk" to (this[HEATMAP] == 1L),
            "decodeOk" to (this[DECODE] == 1L),
        )
        val detail = checks.entries.joinToString(" ") { "${it.key}=${it.value}" }
        val passed = checks.values.all { it }
        return "streak insights ${if (passed) "PASS" else "FAIL"}: $detail"
    }
}
