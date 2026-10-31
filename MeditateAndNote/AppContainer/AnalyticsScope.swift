//
//  AnalyticsScope.swift
//  MeditateAndNote
//

import Foundation
import MeditateAndNoteCore

/// Forwards domain events to the analytics adapter. Read-only cross-cutting
/// side effect: no store or manager state is touched.
struct AnalyticsScope: DomainEventRouting {
    let tracker: any AnalyticsTracking

    init(tracker: any AnalyticsTracking = NoopAnalyticsTracker()) {
        self.tracker = tracker
    }

    static func handles(_ event: DomainEvent) -> Bool {
        switch event {
        case .noteInsightsUpdated:
            return false
        case .noteCreated, .noteUpdated, .noteDeleted, .meditationCompleted,
             .aiDraftGenerated, .aiDraftMetric, .subscriptionChanged:
            return true
        }
    }

    func handle(_ event: DomainEvent) async {
        guard let analyticsEvent = AnalyticsEventMapper.event(for: event) else { return }
        tracker.log(analyticsEvent)
    }
}
