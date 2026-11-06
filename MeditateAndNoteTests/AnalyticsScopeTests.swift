//
//  AnalyticsScopeTests.swift
//  MeditateAndNoteTests
//

import XCTest
@testable import MeditateAndNote
import MeditateAndNoteCore

private final class RecordingTracker: AnalyticsTracking, @unchecked Sendable {
    var events: [String] = []
    var properties: [String: String] = [:]

    func log(_ event: AnalyticsEvent) {
        events.append(event.name)
    }

    func trackScreen(_ name: String) {}

    func setUserProperty(_ value: String, forName name: String) {
        properties[name] = value
    }
}

final class AnalyticsScopeTests: XCTestCase {

    private func scope() -> (AnalyticsScope, RecordingTracker) {
        let tracker = RecordingTracker()
        return (AnalyticsScope(tracker: tracker), tracker)
    }

    func testSubscriptionChangedUpdatesPremiumStatus() async {
        let (scope, tracker) = scope()
        let pro = SubscriptionStatus(
            activeEntitlements: [.pro],
            expirationDate: nil,
            willRenew: true,
            productIdentifier: nil
        )

        await scope.handle(.subscriptionChanged(pro))
        XCTAssertEqual(tracker.properties["premium_status"], "pro")

        await scope.handle(.subscriptionChanged(.none))
        XCTAssertEqual(tracker.properties["premium_status"], "free")
    }

    func testStreakEventsUpdateBucket() async {
        let (scope, tracker) = scope()

        await scope.handle(.streakExtended(currentDays: 5))
        XCTAssertEqual(tracker.properties["streak_bucket"], "4-7")

        await scope.handle(.streakExtended(currentDays: 20))
        XCTAssertEqual(tracker.properties["streak_bucket"], "15+")

        await scope.handle(.streakBroken(previousDays: 20))
        XCTAssertEqual(tracker.properties["streak_bucket"], "0")
    }

    func testStreakBucketBoundaries() {
        XCTAssertEqual(AnalyticsScope.streakBucket(0), "0")
        XCTAssertEqual(AnalyticsScope.streakBucket(3), "1-3")
        XCTAssertEqual(AnalyticsScope.streakBucket(4), "4-7")
        XCTAssertEqual(AnalyticsScope.streakBucket(8), "8-14")
        XCTAssertEqual(AnalyticsScope.streakBucket(15), "15+")
    }
}

/// Firebase validates the API key and the app id itself, and an invalid
/// value raises an Objective-C exception that Swift cannot catch - the app
/// dies at launch. The bootstrap checks first, so a placeholder or a file
/// from another project leaves analytics off instead of killing the app.
final class FirebaseBootstrapTests: XCTestCase {

    private let validKey = "AIzaSy" + String(repeating: "x", count: 33)
    private let validAppID = "1:123456789012:ios:0123456789abcdef0123456789abcdef"
    private let bundleID = "nazar.MeditateAndNote"

    func testAValidConfigIsAccepted() {
        XCTAssertTrue(
            FirebaseBootstrap.isUsable(
                apiKey: validKey,
                appID: validAppID,
                bundleID: bundleID,
                expectedBundleID: bundleID
            )
        )
    }

    func testAPlaceholderAPIKeyIsRejected() {
        XCTAssertFalse(
            FirebaseBootstrap.isUsable(
                apiKey: "AIzaSyPLACEHOLDER",
                appID: validAppID,
                bundleID: bundleID,
                expectedBundleID: bundleID
            )
        )
    }

    func testAnAPIKeyWithoutThePrefixIsRejected() {
        XCTAssertFalse(
            FirebaseBootstrap.isUsable(
                apiKey: String(repeating: "x", count: 39),
                appID: validAppID,
                bundleID: bundleID,
                expectedBundleID: bundleID
            )
        )
    }

    func testAMalformedAppIDIsRejected() {
        XCTAssertFalse(
            FirebaseBootstrap.isUsable(
                apiKey: validKey,
                appID: "1:123:ios",
                bundleID: bundleID,
                expectedBundleID: bundleID
            )
        )
    }

    func testAConfigFromAnotherAppIsRejected() {
        XCTAssertFalse(
            FirebaseBootstrap.isUsable(
                apiKey: validKey,
                appID: validAppID,
                bundleID: "com.somebody.else",
                expectedBundleID: bundleID
            )
        )
    }
}
