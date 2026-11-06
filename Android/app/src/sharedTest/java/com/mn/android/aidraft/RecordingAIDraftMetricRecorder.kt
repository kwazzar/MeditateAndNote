package com.mn.android.aidraft

import com.mn.android.domain.aidraft.AIDraftMetric
import com.mn.android.domain.aidraft.AIDraftMetricRecorder

/** Keeps the telemetry rows in memory instead of the database. */
class RecordingAIDraftMetricRecorder : AIDraftMetricRecorder {

    val metrics: MutableList<AIDraftMetric> = mutableListOf()

    override suspend fun record(metric: AIDraftMetric) {
        metrics += metric
    }
}
