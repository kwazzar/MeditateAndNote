package com.mn.android.infrastructure.persistence.local.ai

import android.content.Context
import com.mn.android.data.AIDraftSource

/**
 * Writes the draft telemetry rows.
 *
 * What happened is decided in the domain - the bridge knows the latency and
 * the outcome of a generation, the editor knows which suggestion was taken or
 * dropped. This layer only persists it, and the row carries counts, latency
 * and a typed kind: never prompt text, never the model's answer.
 */
object AIDraftMetrics {

    suspend fun record(context: Context, metric: AIDraftSource.Metric) {
        MeditateDatabase.get(context).aiDraftMetricDao().insert(
            AiDraftMetricEntity(
                kind = metric.kind,
                warmCold = metric.warmCold,
                latencyMs = metric.latencyMs,
                suggestionCount = metric.suggestionCount,
                errorKind = metric.errorKind,
                suggestionIndex = metric.suggestionIndex,
            ),
        )
    }
}
