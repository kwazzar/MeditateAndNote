//
//  ReminderSettingsTests.swift
//  MeditateAndNoteTests
//

import XCTest
@testable import MeditateAndNote

final class ReminderSettingsTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    private func date(_ day: Int, hour: Int, minute: Int, of month: Int = 9, year: Int = 2026) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps)!
    }

    // MARK: - Invariants

    func testHourClampedToZero() {
        let s = ReminderSettings(isEnabled: true, hour: -5, minute: 10, weekdays: Set([1]))
        XCTAssertEqual(s.hour, 0)
    }

    func testHourClampedToTwentyThree() {
        let s = ReminderSettings(isEnabled: true, hour: 99, minute: 10, weekdays: Set([1]))
        XCTAssertEqual(s.hour, 23)
    }

    func testMinuteClamped() {
        let down = ReminderSettings(isEnabled: true, hour: 10, minute: -1, weekdays: Set([1]))
        let up = ReminderSettings(isEnabled: true, hour: 10, minute: 60, weekdays: Set([1]))
        XCTAssertEqual(down.minute, 0)
        XCTAssertEqual(up.minute, 59)
    }

    func testWeekdaysFilteredToValidRange() {
        let s = ReminderSettings(isEnabled: true, hour: 10, minute: 0, weekdays: Set([0, 1, 8, 5]))
        XCTAssertEqual(s.weekdays, Set([1, 5]))
    }

    func testEmptyWeekdaysFallBackToSunday() {
        let s = ReminderSettings(isEnabled: true, hour: 10, minute: 0, weekdays: [])
        XCTAssertEqual(s.weekdays, Set([1]))
    }

    func testSortedWeekdaysAscending() {
        let s = ReminderSettings(isEnabled: true, hour: 10, minute: 0, weekdays: Set([3, 1, 7]))
        XCTAssertEqual(s.sortedWeekdays, [1, 3, 7])
    }

    // MARK: - ReminderScheduleBuilder

    private func makeBuilder() -> ReminderScheduleBuilder {
        ReminderScheduleBuilder(calendar: calendar)
    }

    func testDisabledSettings_yieldNoDates() {
        let s = ReminderSettings(isEnabled: false, hour: 10, minute: 0, weekdays: Set(1...7))
        XCTAssertTrue(makeBuilder().nextFireDates(settings: s, after: .now, count: 7).isEmpty)
    }

    func testCountZero_yieldsNoDates() {
        let s = ReminderSettings(isEnabled: true, hour: 10, minute: 0, weekdays: Set(1...7))
        XCTAssertTrue(makeBuilder().nextFireDates(settings: s, after: .now, count: 0).isEmpty)
    }

    func testSchedulesOnlySelectedWeekdays() {
        // 2026-09-04 is a Friday (weekday 6). Select Monday (2) and Friday (6).
        let s = ReminderSettings(isEnabled: true, hour: 9, minute: 15, weekdays: Set([2, 6]))
        let after = date(4, hour: 8, minute: 0) // Fri 08:00 — today's slot still ahead
        let dates = makeBuilder().nextFireDates(settings: s, after: after, count: 4)

        XCTAssertEqual(dates.count, 4, "2 weekdays over 2 weeks")
        XCTAssertTrue(dates.allSatisfy { $0 > after }, "All fire dates must be in the future")

        for d in dates {
            let weekday = calendar.component(.weekday, from: d)
            XCTAssertTrue(weekday == 2 || weekday == 6, "Only selected weekdays")
            XCTAssertEqual(calendar.component(.hour, from: d), 9)
            XCTAssertEqual(calendar.component(.minute, from: d), 15)
        }
    }

    func testSameDayBeforeSlot_datesToday() {
        let s = ReminderSettings(isEnabled: true, hour: 20, minute: 0, weekdays: Set(1...7))
        let after = date(4, hour: 10, minute: 0) // Fri 10:00, slot 20:00 later today
        guard let first = makeBuilder().nextFireDates(settings: s, after: after, count: 7).first else {
            return XCTFail("Expected at least one fire date")
        }
        XCTAssertTrue(calendar.isDate(first, inSameDayAs: after), "Today's slot must be included")
        XCTAssertEqual(calendar.component(.hour, from: first), 20)
    }

    func testSameDayAfterSlot_startsTomorrow() {
        let s = ReminderSettings(isEnabled: true, hour: 8, minute: 0, weekdays: Set(1...7))
        let after = date(4, hour: 10, minute: 0) // Fri 10:00, slot 08:00 already passed
        guard let first = makeBuilder().nextFireDates(settings: s, after: after, count: 7).first else {
            return XCTFail("Expected at least one fire date")
        }
        XCTAssertFalse(calendar.isDate(first, inSameDayAs: after), "Passed slot must not fire today")
        XCTAssertTrue(first > after)
    }

    func testRespectsCountLimit() {
        let s = ReminderSettings(isEnabled: true, hour: 8, minute: 0, weekdays: Set(1...7))
        let dates = makeBuilder().nextFireDates(settings: s, after: date(4, hour: 0, minute: 0), count: 3)
        XCTAssertEqual(dates.count, 3)
    }
}