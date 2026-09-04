//
//  DomainModelsTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 04.09.2026.
//

import XCTest
@testable import MeditateAndNote

// MARK: - Note aggregate

final class NoteValueObjectTests: XCTestCase {

    // MARK: NoteTitle

    func testNoteTitle_trimsAndFallsBackToUntitled() {
        XCTAssertEqual(NoteTitle("  Morning  ").rawValue, "Morning")
        XCTAssertEqual(NoteTitle("").rawValue, "Untitled")
        XCTAssertEqual(NoteTitle("\n \t").rawValue, "Untitled")
    }

    func testNoteTitle_equalityAfterNormalization() {
        XCTAssertEqual(NoteTitle(" x "), NoteTitle("x"))
        XCTAssertNotEqual(NoteTitle("x"), NoteTitle("y"))
    }

    func testNoteContent_preservesRawText() {
        XCTAssertEqual(NoteContent("  keep  ").rawValue, "  keep  ")
    }

    // MARK: NoteID

    func testNoteID_roundTripsAsBareUUID() throws {
        let id = NoteID()
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(NoteID.self, from: data)
        XCTAssertEqual(decoded, id)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"\(id.rawValue.uuidString)\"")
    }

    // MARK: Note

    func testNote_codableRoundTrip() throws {
        let note = Note(title: "T", content: "body\nmultiline", date: Date(timeIntervalSince1970: 1_700_000_000))
        let decoded = try JSONDecoder().decode(Note.self, from: try JSONEncoder().encode(note))
        XCTAssertEqual(decoded, note)
    }

    func testNote_updatingContent_preservesIdentityAndDate() {
        let note = Note(title: "T", content: "1", date: Date(timeIntervalSince1970: 100))
        let updated = note.updating(content: NoteContent("2"))

        XCTAssertEqual(updated.id, note.id)
        XCTAssertEqual(updated.title, note.title)
        XCTAssertEqual(updated.date, note.date)
        XCTAssertEqual(updated.content, NoteContent("2"))
    }

    func testNote_retitled_normalizesWhitespace() {
        let note = Note(title: "Old", content: "c")
        XCTAssertEqual(note.retitled("  New  ").title, "New")
        XCTAssertEqual(note.retitled("   ").title, "Untitled")
    }

    // MARK: NoteBook

    func testNoteBook_subscriptAndRemove() {
        let id = NoteID()
        var book = NoteBook(notes: [Note(id: id, title: "A", content: "1")])
        XCTAssertEqual(book[id]?.title, "A")

        book.remove(id)
        XCTAssertNil(book[id])
    }

    func testNoteBook_upsertKeepsOlderAway_whenIncomingIsStale() {
        let id = NoteID()
        let newer = Note(id: id, title: "New", content: "n", date: Date(timeIntervalSince1970: 200))
        var book = NoteBook(notes: [newer])

        book.upsert(Note(id: id, title: "Stale", content: "s", date: Date(timeIntervalSince1970: 100)))

        XCTAssertEqual(book[id], newer, "stale writes must never overwrite a newer version")
    }

    func testNoteBook_merged_sameDateIsNotAConflict() {
        let note = Note(title: "Same", content: "v", date: Date(timeIntervalSince1970: 500))
        let outcome = NoteBook.merged(local: [note], remote: [note])

        XCTAssertEqual(outcome.notes.count, 1)
        XCTAssertTrue(outcome.conflicts.isEmpty, "identical versions across sources are not conflicts")
    }
}

// MARK: - MeditationSession aggregate

final class MeditationSessionTests: XCTestCase {

    func testSessionID_roundTripsAsBareUUID() throws {
        let id = SessionID()
        let data = try JSONEncoder().encode(id)
        XCTAssertEqual(try JSONDecoder().decode(SessionID.self, from: data), id)
    }

    func testSessionDuration_fromPreset_usesRawSeconds() {
        XCTAssertEqual(SessionDuration(.fiveMin).seconds, 300)
        XCTAssertEqual(SessionDuration(.oneMin).seconds, 60)
    }

    func testSessionDuration_decoding_rejectsNonPositive() {
        func decode(_ json: String) throws -> SessionDuration {
            try JSONDecoder().decode(SessionDuration.self, from: Data(json.utf8))
        }
        XCTAssertThrowsError(try decode("0"))
        XCTAssertThrowsError(try decode("-5"))
        XCTAssertEqual(try decode("120").seconds, 120)
    }

    func testSessionDuration_roundTripsAsNumber() throws {
        let duration = SessionDuration(seconds: 90)
        let data = try JSONEncoder().encode(duration)
        XCTAssertEqual(String(data: data, encoding: .utf8), "90")
        XCTAssertEqual(try JSONDecoder().decode(SessionDuration.self, from: data), duration)
    }

    func testMeditationSession_codableAndValueEquality() throws {
        let session = MeditationSession(
            meditationId: "box",
            completedAt: Date(timeIntervalSince1970: 1_000),
            duration: SessionDuration(.fiveMin)
        )
        let decoded = try JSONDecoder().decode(MeditationSession.self, from: try JSONEncoder().encode(session))

        XCTAssertEqual(decoded, session)
        XCTAssertEqual(Set([session, decoded]).count, 1, "equal sessions must collapse in a Set")
    }
}

// MARK: - DailyActivity

final class DailyActivityTests: XCTestCase {

    private func activity(meditation: Bool, note: Bool) -> DailyActivity {
        DailyActivity(date: Date(timeIntervalSince1970: 0), hasMeditation: meditation, hasNote: note)
    }

    func testIsComplete_requiresBothHalves() {
        XCTAssertFalse(activity(meditation: false, note: false).isComplete)
        XCTAssertFalse(activity(meditation: true, note: false).isComplete)
        XCTAssertFalse(activity(meditation: false, note: true).isComplete)
        XCTAssertTrue(activity(meditation: true, note: true).isComplete)
    }

    func testIdentity_isTheDay() {
        let now = Date()
        XCTAssertEqual(DailyActivity(date: now, hasMeditation: false, hasNote: false).id, now)
    }
}

// MARK: - StreakInsight value objects

final class StreakInsightValueTests: XCTestCase {

    private func insight(_ title: String = "A") -> StreakInsight {
        StreakInsight(category: .pattern, title: title, message: "m", value: nil, icon: "star")
    }

    func testStreakInsight_identityIsUUID_notContent() {
        let a = insight("Same")
        let b = insight("Same")

        XCTAssertEqual(a, a)
        XCTAssertNotEqual(a, b, "two generated insights are distinct identities even with equal content")
    }

    func testStreakInsight_setDeduplicatesOnlyByIdentity() {
        let a = insight()
        XCTAssertEqual(Set([a, a, insight()]).count, 2)
    }

    func testRecommendationPriority_order() {
        XCTAssertLessThan(RecommendationPriority.high, .medium)
        XCTAssertLessThan(RecommendationPriority.medium, .low)
        XCTAssertEqual(RecommendationPriority.high.rawValue, 0)
    }

    func testUserRecommendation_identitySemantics() {
        func rec() -> UserRecommendation {
            UserRecommendation(priority: .low, title: "t", message: "m", action: .setReminder, icon: "i")
        }
        let a = rec()
        XCTAssertEqual(Set([a, a, rec()]).count, 2)
    }

    func testRecommendationAction_hashable() {
        XCTAssertEqual(Set([RecommendationAction.setReminder, .setReminder, .navigateToNote]).count, 2)
    }

    func testWeekdayHeatmapDay_hashable() {
        let day = WeekdayHeatmapData.Day(name: "Monday", shortName: "Mon", completionRate: 0.5, totalDays: 4, completeDays: 2)
        XCTAssertEqual(Set([day, day]).count, 1)
    }
}

// MARK: - Meditation aggregate

final class MeditationModelTests: XCTestCase {

    func testMeditationTitle_trimsAndFallsBackToUntitled() {
        XCTAssertEqual(MeditationTitle("  Calm  ").rawValue, "Calm")
        XCTAssertEqual(MeditationTitle(" ").rawValue, "Untitled")
        XCTAssertEqual(MeditationTitle("  Calm  "), MeditationTitle("Calm"))
    }

    func testMeditationID_codableRoundTrip() throws {
        let id: MeditationID = "box-breath"
        let decoded = try JSONDecoder().decode(MeditationID.self, from: try JSONEncoder().encode(id))
        XCTAssertEqual(decoded, id)
    }

    func testMeditation_defaultsToMindfulnessCategory() {
        let m = Meditation(id: "x", title: "T", breathingStyle: .box)
        XCTAssertEqual(m.category, .mindfulness)
        XCTAssertNil(m.description)
    }

    func testMeditation_valueEqualityAndHashing() {
        func make() -> Meditation {
            Meditation(id: "x", title: "T", breathingStyle: .fourSevenEight, description: "d", category: .breathing)
        }
        let a = make()
        let b = make()
        XCTAssertEqual(a, b)
        XCTAssertEqual(Set([a, b]).count, 1, "Meditation identity is value-based, not UUID-generated")
    }

    func testMeditation_carriesDescription_whenProvided() {
        let m = Meditation(id: "x", title: "T", breathingStyle: .box, description: "details")
        XCTAssertEqual(m.description, "details")
    }

    func testMeditationCategory_hasExpectedCases() {
        XCTAssertEqual(MeditationCategory.allCases.map(\.rawValue), [
            "Mindfulness", "Breathing", "Sleep", "Focus", "Relaxation",
        ])
    }

    func testMeditationError_notFound_carriesId() {
        let id = MeditationID(rawValue: "missing")
        let error = MeditationError.notFound(id: id)

        guard case .notFound(let captured) = error else {
            XCTFail("Expected .notFound")
            return
        }
        XCTAssertEqual(captured, id)
    }
}
