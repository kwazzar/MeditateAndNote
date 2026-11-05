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
        case .noteCreated, .noteUpdated, .noteDeleted, .meditationCompleted, .meditationStarted,
             .aiDraftGenerated, .aiDraftMetric, .subscriptionChanged,
             .bookImported, .readerOpened, .bookmarkCreated,
             .streakExtended, .streakBroken:
            return true
        }
    }

    func handle(_ event: DomainEvent) async {
        if let analyticsEvent = AnalyticsEventMapper.event(for: event) {
            tracker.log(analyticsEvent)
        }
        switch event {
        case .subscriptionChanged(let status):
            tracker.setUserProperty(status.isActive(Entitlement.pro) ? "pro" : "free", forName: "premium_status")
        case .streakExtended(let currentDays):
            tracker.setUserProperty(Self.streakBucket(currentDays), forName: "streak_bucket")
        case .streakBroken:
            tracker.setUserProperty("0", forName: "streak_bucket")
        default:
            break
        }
    }

    static func streakBucket(_ days: Int) -> String {
        switch days {
        case ...0: return "0"
        case 1...3: return "1-3"
        case 4...7: return "4-7"
        case 8...14: return "8-14"
        default: return "15+"
        }
    }
}
