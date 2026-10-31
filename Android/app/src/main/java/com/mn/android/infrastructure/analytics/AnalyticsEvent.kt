package com.mn.android.infrastructure.analytics

/** Provider-independent event payload; Firebase mapping lives in the tracker. */
data class AnalyticsEvent(
    val name: String,
    val params: Map<String, Any> = emptyMap(),
)
