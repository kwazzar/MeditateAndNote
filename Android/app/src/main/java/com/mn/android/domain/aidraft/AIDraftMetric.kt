package com.mn.android.domain.aidraft

/**
 * One telemetry event: counts, latency and a typed kind - never content.
 *
 * The kind is the bridge's own name for the event ("generationStarted", …).
 * It is stored as it is and mapped to a domain event at the edge.
 */
data class AIDraftMetric(
    val kind: String,
    val warmCold: Boolean? = null,
    val latencyMs: Long? = null,
    val suggestionCount: Long? = null,
    val errorKind: String? = null,
    val suggestionIndex: Long? = null,
)
