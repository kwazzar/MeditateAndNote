package com.mn.android.data

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Flat Room projection of Swift's `AIDraftMetric`.
 *
 * Swift models this as an enum with associated values; Room cannot store that, so
 * the mapping lives here in Infrastructure rather than leaking a flattening into
 * the domain. `kindRawValue` is already the stable scalar label the domain
 * exposes for exactly this purpose.
 */
@Entity(tableName = "ai_draft_metrics")
data class AiDraftMetricEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    @ColumnInfo(name = "kind") val kind: String,
    @ColumnInfo(name = "warm_cold") val warmCold: Boolean? = null,
    @ColumnInfo(name = "latency_ms") val latencyMs: Long? = null,
    @ColumnInfo(name = "suggestion_count") val suggestionCount: Long? = null,
    @ColumnInfo(name = "error_kind") val errorKind: String? = null,
    @ColumnInfo(name = "suggestion_index") val suggestionIndex: Long? = null,
)