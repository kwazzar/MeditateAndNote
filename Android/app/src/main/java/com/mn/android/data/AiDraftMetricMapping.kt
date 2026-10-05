package com.mn.android.data

import com.mn.core.AIDraftMetric
import org.swift.swiftkit.core.SwiftMemoryManagement

/**
 * `AIDraftMetric` (Swift enum with associated values) <-> Room row.
 *
 * Lives in Infrastructure on purpose: the domain owns the enum, but only this
 * layer knows about SQLite columns. The discriminator is used as the row's
 * `kind` because jextract surfaces Swift's raw enum cases verbatim.
 */
fun AIDraftMetric.toEntity(): AiDraftMetricEntity {
    val arena = SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA
    val kind = discriminator.name
    return when (val case = getCase(arena)) {
        is AIDraftMetric.Case.GenerationStarted ->
            AiDraftMetricEntity(kind = kind, warmCold = case.warmCold())

        is AIDraftMetric.Case.GenerationCompleted ->
            AiDraftMetricEntity(
                kind = kind,
                latencyMs = case.latencyMs(),
                suggestionCount = case.suggestionCount(),
            )

        is AIDraftMetric.Case.GenerationFailed ->
            AiDraftMetricEntity(kind = kind, errorKind = case.errorKind().getDiscriminator().name)

        is AIDraftMetric.Case.SuggestionInserted ->
            AiDraftMetricEntity(kind = kind, suggestionIndex = case.index())

        is AIDraftMetric.Case.SuggestionRejected ->
            AiDraftMetricEntity(kind = kind, suggestionIndex = case.index())
    }
}