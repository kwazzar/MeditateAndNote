//
//  StreakActivityMarkerTests.swift
//  MeditateAndNoteCoreJNITests
//
//  Android has no DomainEventBus, so the streak bookkeeping happens where the
//  activity is recorded: the meditation path marks the day when the session
//  ends, the note path when the note is saved. These tests lock the invariant
//  both paths share — a day counts toward the streak only when it holds BOTH a
//  meditation and a note, and it counts once.
//

import XCTest
@testable import MeditateAndNoteCoreJNI
import MeditateAndNoteCore

final class StreakActivityMarkerTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }

    private func emptySnapshot() -> StreakSnapshot {
        StreakSnapshot(activities: [], currentStreak: 0, longestStreak: 0, lastCountedDay: nil)
    }

    // MARK: - Note completes a meditated day

    func testNoteOnMeditatedDay_completesDayAndCountsStreak() {
        let today = day(2026, 8, 20)
        let meditated = streakMarkMeditation(emptySnapshot(), completedAt: today, calendar: calendar)
        XCTAssertEqual(meditated.currentStreak, 0, "Meditation alone does not complete the day")

        let noted = streakMarkNote(meditated, noteDate: today, calendar: calendar)
        XCTAssertEqual(noted.currentStreak, 1, "Meditation + note on the same day counts")
        XCTAssertEqual(noted.longestStreak, 1)
        XCTAssertTrue(noted.activities.first?.hasNote == true)
        XCTAssertTrue(noted.activities.first?.hasMeditation == true)
    }

    func testNoteBeforeMeditation_orderDoesNotMatter() {
        let today = day(2026, 8, 20)
        let noted = streakMarkNote(emptySnapshot(), noteDate: today, calendar: calendar)
        XCTAssertEqual(noted.currentStreak, 0)

        let meditated = streakMarkMeditation(noted, completedAt: today, calendar: calendar)
        XCTAssertEqual(meditated.currentStreak, 1)
    }

    func testNoteWithoutMeditation_doesNotCountStreak() {
        let today = day(2026, 8, 20)
        let noted = streakMarkNote(emptySnapshot(), noteDate: today, calendar: calendar)

        XCTAssertEqual(noted.currentStreak, 0, "A note alone is a partial day")
        XCTAssertTrue(noted.activities.first?.hasNote == true)
    }

    func testDuplicateNoteMarking_doesNotInflateStreak() {
        let today = day(2026, 8, 20)
        var snapshot = streakMarkMeditation(emptySnapshot(), completedAt: today, calendar: calendar)
        snapshot = streakMarkNote(snapshot, noteDate: today, calendar: calendar)
        snapshot = streakMarkNote(snapshot, noteDate: today, calendar: calendar)

        XCTAssertEqual(snapshot.currentStreak, 1)
        XCTAssertEqual(snapshot.longestStreak, 1)
    }

    func testConsecutiveDaysWithNoteAndMeditation_buildStreak() {
        let day1 = day(2026, 8, 19)
        let day2 = day(2026, 8, 20)

        var snapshot = emptySnapshot()
        for day in [day1, day2] {
            snapshot = streakMarkMeditation(snapshot, completedAt: day, calendar: calendar)
            snapshot = streakMarkNote(snapshot, noteDate: day, calendar: calendar)
        }

        XCTAssertEqual(snapshot.currentStreak, 2)
        XCTAssertEqual(snapshot.longestStreak, 2)
    }
}
