//
//  AnalyticsEventMapperTests.swift
//  MeditateAndNoteTests
//

import XCTest
@testable import MeditateAndNote
import MeditateAndNoteCore

final class AnalyticsEventMapperTests: XCTestCase {

    private let note = Note()

    func testNoteEvents() {
        XCTAssertEqual(AnalyticsEventMapper.event(for: .noteCreated(note))?.name, "note_created")
        XCTAssertEqual(AnalyticsEventMapper.event(for: .noteUpdated(note))?.name, "note_updated")
        XCTAssertEqual(AnalyticsEventMapper.event(for: .noteDeleted(note.id))?.name, "note_deleted")
    }

    func testMeditationCompletedCarriesOnlyDurationAndBuiltInID() {
        let session = MeditationSession(
            meditationId: MeditationID(rawValue: "box"),
            completedAt: .now,
            duration: SessionDuration(seconds: 300)
        )

        let event = AnalyticsEventMapper.event(for: .meditationCompleted(session))

        XCTAssertEqual(event?.name, "meditation_completed")
        XCTAssertEqual(event?.parameters["meditation_id"], .string("box"))
        XCTAssertEqual(event?.parameters["duration_seconds"], .int(300))
        XCTAssertEqual(event?.parameters.count, 2)
    }

    func testAIEvents() {
        XCTAssertEqual(
            AnalyticsEventMapper.event(for: .aiDraftGenerated(noteID: note.id, sessionID: UUID()))?.name,
            "ai_draft_generated"
        )

        let started = AnalyticsEventMapper.event(for: .aiDraftMetric(event: .generationStarted(warmCold: true)))
        XCTAssertEqual(started?.name, "ai_draft_metric")
        XCTAssertEqual(started?.parameters["metric_type"], .string("generation_started"))
        XCTAssertEqual(started?.parameters["warm_cold"], .bool(true))

        let failed = AnalyticsEventMapper.event(for: .aiDraftMetric(event: .generationFailed(errorKind: .timeout)))
        XCTAssertEqual(failed?.parameters["error_kind"], .string("timeout"))
    }

    func testSubscriptionEvent() {
        let status = SubscriptionStatus(
            activeEntitlements: [.pro],
            expirationDate: .now,
            willRenew: true,
            productIdentifier: "pro_monthly"
        )

        let event = AnalyticsEventMapper.event(for: .subscriptionChanged(status))

        XCTAssertEqual(event?.name, "subscription_changed")
        XCTAssertEqual(event?.parameters, ["is_premium": .bool(true)])
    }

    func testNoisyInsightsEventIsDropped() {
        XCTAssertNil(AnalyticsEventMapper.event(for: .noteInsightsUpdated([note.id])))
    }

    func testEventNamesStayWithinFirebaseLimit() {
        let events: [DomainEvent] = [
            .noteCreated(note),
            .noteUpdated(note),
            .noteDeleted(note.id),
            .meditationCompleted(MeditationSession(
                meditationId: MeditationID(rawValue: "box"),
                duration: SessionDuration(seconds: 60)
            )),
            .aiDraftGenerated(noteID: note.id, sessionID: UUID()),
            .aiDraftMetric(event: .generationStarted(warmCold: false)),
            .subscriptionChanged(.none),
        ]

        for event in events {
            let mapped = AnalyticsEventMapper.event(for: event)
            XCTAssertNotNil(mapped)
            XCTAssertLessThanOrEqual(mapped!.name.count, 40)
            XCTAssertLessThanOrEqual(mapped!.parameters.count, 50)
        }
    }
}
