//
//  FirebaseAnalyticsTracker.swift
//  MeditateAndNote
//

import FirebaseAnalytics
import FirebaseCore
import Foundation

/// Firebase adapter. Guarded on `FirebaseBootstrap.isConfigured` so
/// previews/tests without `GoogleService-Info.plist` stay silent instead of
/// crashing.
final class FirebaseAnalyticsTracker: AnalyticsTracking, @unchecked Sendable {
    func log(_ event: AnalyticsEvent) {
        guard FirebaseBootstrap.isConfigured else { return }
        Analytics.logEvent(event.name, parameters: event.parameters.mapValues(\.firebaseValue))
    }

    func trackScreen(_ name: String) {
        guard FirebaseBootstrap.isConfigured else { return }
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: name,
                AnalyticsParameterScreenClass: name,
            ]
        )
    }
}

private extension AnalyticsEvent.Value {
    var firebaseValue: Any {
        switch self {
        case let .string(value): return value
        case let .int(value): return value
        case let .double(value): return value
        case let .bool(value): return value
        }
    }
}
