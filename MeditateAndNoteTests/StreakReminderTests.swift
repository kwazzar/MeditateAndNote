//
//  StreakReminderTests.swift
//  MeditateAndNoteTests
//
//  Covers the "meditation done, note missing" state that drives the streak
//  reminder banner and the today-cell reminder dot.
//

import XCTest
@testable import MeditateAndNote

final class StreakReminderTests: XCTestCase {

    private var defaults: UserDefaults!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "StreakReminderTests_\(UUID().uuidString)")!
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.volatileDomainNames.first ?? "")
        super.tearDown()
    }

    private func makeSUT() -> StreakTracker {
        StreakTracker(calendar: calendar, defaults: defaults)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.date(from: comps)!
    }

    // MARK: - Detection helpers
    //
    // The banner shows when today has meditation but no note (isComplete is
    // false while hasMeditation is true). These assert the domain values the
    // view reads, keeping the presentation-led rule testable against the
    // StreakTracker without needing a view.

    func testMeditationWithoutNote_isIncompleteButHasMeditation() async {
        let tracker = makeSUT()
        let today = date(2026, 8, 20)

        await tracker.markMeditationCompleted(date: today)

        let item = tracker.activity(for: today)
        XCTAssertTrue(item.hasMeditation, "Meditation is recorded")
        XCTAssertFalse(item.hasNote, "No note yet")
        XCTAssertFalse(item.isComplete, "Day is not complete until a note is added")
    }

    func testNoteAfterMeditation_makesDayComplete() async {
        let tracker = makeSUT()
        let today = date(2026, 8, 20)

        await tracker.markMeditationCompleted(date: today)
        await tracker.markNoteCreated(date: today)

        let item = tracker.activity(for: today)
        XCTAssertTrue(item.isComplete, "Both actions present → complete")
    }

    func testAfterNoteReminderStateClears() async {
        let tracker = makeSUT()
        let today = date(2026, 8, 20)

        await tracker.markMeditationCompleted(date: today)
        await tracker.markNoteCreated(date: today)

        let item = tracker.activity(for: today)
        XCTAssertFalse(item.hasMeditation && !item.hasNote,
                       "Once the note exists the reminder state must clear")
    }

    // MARK: - DayCell reminder condition

    func testReminderCondition_trueWhenMeditationWithoutNote() {
        let item = DailyActivity(date: Date(), hasMeditation: true, hasNote: false)
        XCTAssertTrue(item.hasMeditation && !item.hasNote)
        XCTAssertFalse(item.isComplete)
    }

    func testReminderCondition_falseWhenComplete() {
        let item = DailyActivity(date: Date(), hasMeditation: true, hasNote: true)
        XCTAssertFalse(item.hasMeditation && !item.hasNote)
        XCTAssertTrue(item.isComplete)
    }

    func testReminderCondition_falseWhenOnlyNote() {
        let item = DailyActivity(date: Date(), hasMeditation: false, hasNote: true)
        XCTAssertFalse(item.hasMeditation && !item.hasNote)
        XCTAssertFalse(item.isComplete)
    }

    // MARK: - Presentational mapping

    func testDayCellNeedNoteFlag_derivedFromActivity() {
        let cases: [(DailyActivity, Bool)] = [
            (DailyActivity(date: Date(), hasMeditation: true, hasNote: false), true),
            (DailyActivity(date: Date(), hasMeditation: true, hasNote: true), false),
            (DailyActivity(date: Date(), hasMeditation: false, hasNote: true), false),
            (DailyActivity(date: Date(), hasMeditation: false, hasNote: false), false),
        ]

        for (item, expected) in cases {
            let needsNote = item.hasMeditation && !item.hasNote
            XCTAssertEqual(needsNote, expected, "needsNote must only be true when meditation present but note missing")
        }
    }
}
