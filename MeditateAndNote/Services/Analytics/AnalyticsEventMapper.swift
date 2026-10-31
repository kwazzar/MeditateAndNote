//
//  AnalyticsEventMapper.swift
//  MeditateAndNote
//

import Foundation
import MeditateAndNoteCore

/// Maps domain events to Firebase Analytics event names and scalar parameters.
///
/// Privacy boundary: never emit note content, note IDs, book IDs, prompts,
/// suggestions, or raw provider messages. IDs that are stable, non-user data
/// (the built-in meditation identifier) are allowed.
enum AnalyticsEventMapper {
    static func event(for event: DomainEvent) -> AnalyticsEvent? {
        switch event {
        case .noteCreated:
            return AnalyticsEvent(name: "note_created")
        case .noteUpdated:
            return AnalyticsEvent(name: "note_updated")
        case .noteDeleted:
            return AnalyticsEvent(name: "note_deleted")
        case let .meditationCompleted(session):
            return AnalyticsEvent(
                name: "meditation_completed",
                parameters: [
                    "meditation_id": .string(session.meditationId.rawValue),
                    "duration_seconds": .int(Int(session.duration.seconds.rounded())),
                ]
            )
        case .aiDraftGenerated:
            return AnalyticsEvent(name: "ai_draft_generated")
        case let .aiDraftMetric(metric):
            return metricEvent(for: metric)
        case .noteInsightsUpdated:
            return nil
        case let .subscriptionChanged(status):
            return AnalyticsEvent(
                name: "subscription_changed",
                parameters: ["is_premium": .bool(status.isActive(.pro))]
            )
        }
    }

    private static func metricEvent(for metric: AIDraftMetric) -> AnalyticsEvent {
        switch metric {
        case let .generationStarted(warmCold):
            return AnalyticsEvent(
                name: "ai_draft_metric",
                parameters: [
                    "metric_type": .string("generation_started"),
                    "warm_cold": .bool(warmCold),
                ]
            )
        case let .generationCompleted(latencyMs, suggestionCount):
            return AnalyticsEvent(
                name: "ai_draft_metric",
                parameters: [
                    "metric_type": .string("generation_completed"),
                    "latency_ms": .int(latencyMs),
                    "suggestion_count": .int(suggestionCount),
                ]
            )
        case let .generationFailed(errorKind):
            return AnalyticsEvent(
                name: "ai_draft_metric",
                parameters: [
                    "metric_type": .string("generation_failed"),
                    "error_kind": .string(errorKind.rawValue),
                ]
            )
        case let .suggestionInserted(index):
            return AnalyticsEvent(
                name: "ai_draft_metric",
                parameters: [
                    "metric_type": .string("suggestion_inserted"),
                    "index": .int(index),
                ]
            )
        case let .suggestionRejected(index):
            return AnalyticsEvent(
                name: "ai_draft_metric",
                parameters: [
                    "metric_type": .string("suggestion_rejected"),
                    "index": .int(index),
                ]
            )
        }
    }
}
