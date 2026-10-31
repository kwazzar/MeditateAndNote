//
//  AnalyticsTracking.swift
//  MeditateAndNote
//

import Foundation

protocol AnalyticsTracking: Sendable {
    func log(_ event: AnalyticsEvent)
    func trackScreen(_ name: String)
}

/// Used by previews and tests where no Firebase app is configured.
struct NoopAnalyticsTracker: AnalyticsTracking {
    func log(_ event: AnalyticsEvent) {}
    func trackScreen(_ name: String) {}
}
