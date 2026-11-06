package com.mn.android.infrastructure.persistence.local.ai

import android.content.Context
import com.mn.android.domain.aidraft.AIDraftMetric
import com.mn.android.domain.aidraft.AIDraftMetricRecorder

/**
 * Writes the draft telemetry rows.
 *
 * What happened is decided in the domain - the bridge knows the latency and
 * the outcome of a generation, the editor knows which suggestion was taken or
 * dropped. This layer only persists it, and the row carries counts, latency
 * and a typed kind: never prompt text, never the model's answer.
 */
object AIDraftMetrics : AIDraftMetricRecorder {

    private var context: Context? = null

    fun configure(context: Context) {
        this.context = context.applicationContext
    }

    override suspend fun record(metric: AIDraftMetric) {
        val context = this.context ?: return
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
