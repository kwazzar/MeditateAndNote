package com.mn.android.domain.aidraft

/**
 * Where the draft telemetry lands.
 *
 * What happened is decided in the domain - the bridge knows the latency and
 * the outcome of a generation, the editor knows which suggestion was taken or
 * dropped. This port only records it.
 */
interface AIDraftMetricRecorder {
    suspend fun record(metric: AIDraftMetric)
}
