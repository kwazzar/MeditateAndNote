//
//  EventRoutingTableTests.swift
//  MeditateAndNoteTests
//
//  Locks the `DomainEventRouting.handles` table that `AppContainer.handlers(for:)`
//  uses to decide which scopes to build. A wrong entry fails silently: the scope
//  is never built, so its `handle(_:)` never runs and the side effect vanishes.
//  Adding a `DomainEvent` case breaks the exhaustive switch in every `handles`,
//  but only this test notices when the routing itself is wrong.
//

import XCTest
@testable import MeditateAndNote

final class EventRoutingTableTests: XCTestCase {

    private let note = Note()
    private let session = MeditationSession(
        meditationId: MeditationID(rawValue: "1"),
        completedAt: .now,
        duration: SessionDuration(seconds: 60)
    )

    /// Every `DomainEvent` case paired with the scopes that must react to it,
    /// in the order `AppContainer.handlers(for:)` appends them.
    private var routingTable: [(event: DomainEvent, scopes: [String])] {
        [
            (.noteCreated(note), ["streak", "notes"]),
            (.noteUpdated(note), ["streak", "notes"]),
            (.noteDeleted(note.id), ["streak", "notes", "aiDraft", "search"]),
            (.meditationCompleted(session), ["streak", "meditation"]),
            (.aiDraftGenerated(noteID: note.id, sessionID: UUID()), []),
            (.aiDraftMetric(event: .generationStarted(warmCold: true)), ["aiDraft"]),
            // Published BY NoteInsightManager, consumed only by
            // NoteInsightsViewModel's own bus subscription. No scope mutates.
            (.noteInsightsUpdated([note.id]), []),
        ]
    }

    private func routedScopes(for event: DomainEvent) -> [String] {
        var result: [String] = []
        if StreakScope.handles(event) { result.append("streak") }
        if NoteScope.handles(event) { result.append("notes") }
        if AIDraftScope.handles(event) { result.append("aiDraft") }
        if MeditationScope.handles(event) { result.append("meditation") }
        if SearchScope.handles(event) { result.append("search") }
        return result
    }

    func testRoutingTable() {
        for (event, expected) in routingTable {
            XCTAssertEqual(routedScopes(for: event), expected, "wrong routing for \(event)")
        }
    }
}
