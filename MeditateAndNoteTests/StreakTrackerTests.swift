//
//  StreakTrackerTests.swift
//  MeditateAndNoteTests
//

import XCTest
@testable import MeditateAndNote

final class StreakTrackerTests: XCTestCase {

    private var defaults: UserDefaults!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "StreakTrackerTests_\(UUID().uuidString)")!
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

    private func startOfToday() -> Date {
        calendar.startOfDay(for: Date())
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }

    private func yesterday(from ref: Date) -> Date {
        ref.addingTimeInterval(-86_400)
    }

    private func tomorrow(from ref: Date) -> Date {
        ref.addingTimeInterval(86_400)
    }

    // MARK: - Same-day note + meditation → streak +1

    func testSameDayNoteAndMeditation_streakIncreasesByOne() {
        let tracker = makeSUT()
        let today = date(year: 2026, month: 8, day: 20)

        tracker.markNoteCreated(date: today)
        XCTAssertEqual(tracker.currentStreak, 0, "Streak should stay 0 before both actions are done")

        tracker.markMeditationCompleted(date: today)
        XCTAssertEqual(tracker.currentStreak, 1, "Both actions on same day → streak = 1")
        XCTAssertTrue(tracker.isTodayComplete || tracker.activity(for: today).isComplete)
    }

    func testSameDayMeditationThenNote_streakIncreasesByOne() {
        let tracker = makeSUT()
        let today = date(year: 2026, month: 8, day: 20)

        tracker.markMeditationCompleted(date: today)
        XCTAssertEqual(tracker.currentStreak, 0)

        tracker.markNoteCreated(date: today)
        XCTAssertEqual(tracker.currentStreak, 1, "Order should not matter")
    }

    // MARK: - Partial day (only one action) → no streak

    func testOnlyNote_noStreakIncrease() {
        let tracker = makeSUT()
        let today = date(year: 2026, month: 8, day: 20)

        tracker.markNoteCreated(date: today)

        XCTAssertEqual(tracker.currentStreak, 0)
        XCTAssertFalse(tracker.activity(for: today).isComplete)
    }

    func testOnlyMeditation_noStreakIncrease() {
        let tracker = makeSUT()
        let today = date(year: 2026, month: 8, day: 20)

        tracker.markMeditationCompleted(date: today)

        XCTAssertEqual(tracker.currentStreak, 0)
        XCTAssertFalse(tracker.activity(for: today).isComplete)
    }

    // MARK: - Consecutive days → streak builds

    func testConsecutiveDays_streakBuilds() {
        let tracker = makeSUT()
        let day1 = date(year: 2026, month: 8, day: 18)
        let day2 = date(year: 2026, month: 8, day: 19)
        let day3 = date(year: 2026, month: 8, day: 20)

        // Day 1: complete
        tracker.markNoteCreated(date: day1)
        tracker.markMeditationCompleted(date: day1)
        XCTAssertEqual(tracker.currentStreak, 1)

        // Day 2: complete
        tracker.markNoteCreated(date: day2)
        tracker.markMeditationCompleted(date: day2)
        XCTAssertEqual(tracker.currentStreak, 2)

        // Day 3: complete
        tracker.markNoteCreated(date: day3)
        tracker.markMeditationCompleted(date: day3)
        XCTAssertEqual(tracker.currentStreak, 3)
        XCTAssertEqual(tracker.longestStreak, 3)
    }

    // MARK: - Gap → streak resets

    func testGapBetweenCompleteDays_streakResets() {
        let tracker = makeSUT()
        let day1 = date(year: 2026, month: 8, day: 16)
        let day2 = date(year: 2026, month: 8, day: 17)
        let day3 = date(year: 2026, month: 8, day: 19) // gap: day 18 missing

        // Day 1: complete
        tracker.markNoteCreated(date: day1)
        tracker.markMeditationCompleted(date: day1)
        XCTAssertEqual(tracker.currentStreak, 1)

        // Day 2: complete
        tracker.markNoteCreated(date: day2)
        tracker.markMeditationCompleted(date: day2)
        XCTAssertEqual(tracker.currentStreak, 2)

        // Day 3: complete (day 18 was missed → streak resets to 1)
        tracker.markNoteCreated(date: day3)
        tracker.markMeditationCompleted(date: day3)
        XCTAssertEqual(tracker.currentStreak, 1, "Gap on day 18 → streak resets to 1 on day 19")
        XCTAssertEqual(tracker.longestStreak, 2, "Longest streak should remain 2")
    }

    // MARK: - Partial days don't break streak, but don't extend it

    func testPartialDayBetweenCompleteDays_doesNotExtendStreak() {
        let tracker = makeSUT()
        let day1 = date(year: 2026, month: 8, day: 18)
        let day2 = date(year: 2026, month: 8, day: 19) // only note
        let day3 = date(year: 2026, month: 8, day: 20)

        // Day 1: complete
        tracker.markNoteCreated(date: day1)
        tracker.markMeditationCompleted(date: day1)
        XCTAssertEqual(tracker.currentStreak, 1)

        // Day 2: only note (not complete)
        tracker.markNoteCreated(date: day2)
        XCTAssertEqual(tracker.currentStreak, 1, "Partial day should not change streak")
        XCTAssertFalse(tracker.activity(for: day2).isComplete)

        // Day 3: complete (yesterday was NOT complete → streak = 1)
        tracker.markNoteCreated(date: day3)
        tracker.markMeditationCompleted(date: day3)
        XCTAssertEqual(tracker.currentStreak, 1, "Yesterday was incomplete → streak = 1")
    }

    // MARK: - Order independence

    func testOrderIndependence_meditationFirst() {
        let tracker = makeSUT()
        let day = date(year: 2026, month: 8, day: 20)

        tracker.markMeditationCompleted(date: day)
        XCTAssertFalse(tracker.activity(for: day).isComplete)
        XCTAssertEqual(tracker.currentStreak, 0)

        tracker.markNoteCreated(date: day)
        XCTAssertTrue(tracker.activity(for: day).isComplete)
        XCTAssertEqual(tracker.currentStreak, 1)
    }

    func testOrderIndependence_noteFirst() {
        let tracker = makeSUT()
        let day = date(year: 2026, month: 8, day: 20)

        tracker.markNoteCreated(date: day)
        XCTAssertFalse(tracker.activity(for: day).isComplete)
        XCTAssertEqual(tracker.currentStreak, 0)

        tracker.markMeditationCompleted(date: day)
        XCTAssertTrue(tracker.activity(for: day).isComplete)
        XCTAssertEqual(tracker.currentStreak, 1)
    }

    // MARK: - Duplicate calls are idempotent

    func testDuplicateCallsAreIdempotent() {
        let tracker = makeSUT()
        let day = date(year: 2026, month: 8, day: 20)

        tracker.markNoteCreated(date: day)
        tracker.markNoteCreated(date: day) // duplicate
        tracker.markMeditationCompleted(date: day)
        tracker.markMeditationCompleted(date: day) // duplicate

        XCTAssertEqual(tracker.currentStreak, 1)
        XCTAssertTrue(tracker.activity(for: day).isComplete)
    }

    func testDuplicateMarksOnConsecutiveDays_doNotInflateStreak() {
        let tracker = makeSUT()
        let day1 = date(year: 2026, month: 8, day: 19)
        let day2 = date(year: 2026, month: 8, day: 20)

        tracker.markNoteCreated(date: day1)
        tracker.markMeditationCompleted(date: day1)
        XCTAssertEqual(tracker.currentStreak, 1)

        tracker.markNoteCreated(date: day2)
        tracker.markMeditationCompleted(date: day2)
        XCTAssertEqual(tracker.currentStreak, 2)

        tracker.markNoteCreated(date: day2) // duplicate after complete predecessor
        tracker.markMeditationCompleted(date: day2) // duplicate
        XCTAssertEqual(tracker.currentStreak, 2, "Duplicate marks on an already counted day must not inflate the streak")
        XCTAssertEqual(tracker.longestStreak, 2)
    }

    func testDuplicateMarksSurviveRecreation() {
        let today = startOfToday()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        do {
            let tracker = makeSUT()
            tracker.markNoteCreated(date: yesterday)
            tracker.markMeditationCompleted(date: yesterday)
            tracker.markNoteCreated(date: today)
            tracker.markMeditationCompleted(date: today)
            XCTAssertEqual(tracker.currentStreak, 2)
        }

        do {
            let tracker = makeSUT()
            XCTAssertEqual(tracker.currentStreak, 2)
            tracker.markNoteCreated(date: today) // duplicate across instance recreation
            tracker.markMeditationCompleted(date: today)
            XCTAssertEqual(tracker.currentStreak, 2, "Counted-day memory must persist across instances")
        }
    }

    // MARK: - fullRecalculation

    func testFullRecalculation_rebuildsStreakFromHistory() {
        let tracker = makeSUT()

        let noteDates = [
            date(year: 2026, month: 8, day: 18),
            date(year: 2026, month: 8, day: 19),
            date(year: 2026, month: 8, day: 20),
            date(year: 2026, month: 8, day: 22), // gap: day 21
        ]
        let meditationDates = [
            date(year: 2026, month: 8, day: 18),
            date(year: 2026, month: 8, day: 19),
            date(year: 2026, month: 8, day: 22),
        ]

        tracker.fullRecalculation(ActivityHistory(noteDates: noteDates, meditationDates: meditationDates))

        XCTAssertTrue(tracker.activity(for: date(year: 2026, month: 8, day: 18)).isComplete)
        XCTAssertTrue(tracker.activity(for: date(year: 2026, month: 8, day: 19)).isComplete)
        XCTAssertFalse(tracker.activity(for: date(year: 2026, month: 8, day: 20)).isComplete, "Day 20 has note but no meditation")
        XCTAssertFalse(tracker.activity(for: date(year: 2026, month: 8, day: 21)).isComplete, "Day 21 has nothing")
        XCTAssertTrue(tracker.activity(for: date(year: 2026, month: 8, day: 22)).isComplete)

        XCTAssertEqual(tracker.currentStreak, 1, "Current streak ends at day 22 (day 21 gap)")
        XCTAssertEqual(tracker.longestStreak, 2, "Longest streak is days 18-19")
    }

    func testFullRecalculation_allConsecutive() {
        let tracker = makeSUT()

        let dates = (18...20).map { date(year: 2026, month: 8, day: $0) }
        tracker.fullRecalculation(ActivityHistory(noteDates: dates, meditationDates: dates))

        XCTAssertEqual(tracker.currentStreak, 3)
        XCTAssertEqual(tracker.longestStreak, 3)
    }

    func testFullRecalculation_emptyHistory() {
        let tracker = makeSUT()

        tracker.fullRecalculation(ActivityHistory())

        XCTAssertEqual(tracker.currentStreak, 0)
        XCTAssertEqual(tracker.longestStreak, 0)
        XCTAssertTrue(tracker.dailyActivities.isEmpty)
    }

    // MARK: - Midnight boundary

    func testMidnightBoundary_differentDaysAreDifferentKeys() {
        let tracker = makeSUT()
        let day1 = date(year: 2026, month: 8, day: 20)
        let day2 = date(year: 2026, month: 8, day: 21)

        tracker.markNoteCreated(date: day1)
        tracker.markMeditationCompleted(date: day1)
        XCTAssertEqual(tracker.currentStreak, 1)

        tracker.markNoteCreated(date: day2)
        tracker.markMeditationCompleted(date: day2)
        XCTAssertEqual(tracker.currentStreak, 2)
    }

    func testMidnightBoundary_exactMidnightDatesAreNormalized() {
        let tracker = makeSUT()

        // Two different times on the same day
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 20
        comps.hour = 2; comps.minute = 30
        let earlyMorning = calendar.date(from: comps)!

        comps.hour = 23; comps.minute = 59
        let lateNight = calendar.date(from: comps)!

        tracker.markNoteCreated(date: earlyMorning)
        tracker.markMeditationCompleted(date: lateNight)

        let activity = tracker.activity(for: earlyMorning)
        XCTAssertTrue(activity.isComplete, "Both actions on same calendar day, different times")
        XCTAssertEqual(tracker.currentStreak, 1)
    }

    // MARK: - Longest streak tracking

    func testLongestStreak_doesNotDecrease() {
        let tracker = makeSUT()

        // Build streak of 3
        let d1 = date(year: 2026, month: 8, day: 15)
        let d2 = date(year: 2026, month: 8, day: 16)
        let d3 = date(year: 2026, month: 8, day: 17)
        for d in [d1, d2, d3] {
            tracker.markNoteCreated(date: d)
            tracker.markMeditationCompleted(date: d)
        }
        XCTAssertEqual(tracker.longestStreak, 3)

        // Gap then restart
        let d5 = date(year: 2026, month: 8, day: 19)
        tracker.markNoteCreated(date: d5)
        tracker.markMeditationCompleted(date: d5)
        XCTAssertEqual(tracker.currentStreak, 1)
        XCTAssertEqual(tracker.longestStreak, 3, "Longest streak should remain 3")
    }

    // MARK: - checkStreakBreak

    func testCheckStreakBreak_yesterdayIncomplete_todayIncomplete_streakZero() {
        let tracker = makeSUT()
        let today = date(year: 2026, month: 8, day: 20)
        let yesterday = date(year: 2026, month: 8, day: 19)

        // Yesterday incomplete (only note)
        tracker.markNoteCreated(date: yesterday)
        XCTAssertEqual(tracker.currentStreak, 0)

        // Check streak break — today is also incomplete
        tracker.checkStreakBreak()
        XCTAssertEqual(tracker.currentStreak, 0)
    }

    // MARK: - Persistence round-trip

    func testPersistence_survivesRecreation() {
        let today = startOfToday()

        // Create tracker, record activity
        do {
            let tracker = makeSUT()
            tracker.markNoteCreated(date: today)
            tracker.markMeditationCompleted(date: today)
            XCTAssertEqual(tracker.currentStreak, 1)
        }

        // Create new tracker with same defaults — should load persisted state
        do {
            let tracker = makeSUT()
            XCTAssertEqual(tracker.currentStreak, 1, "Streak should persist across instances")
            XCTAssertEqual(tracker.activity(for: today).hasNote, true)
            XCTAssertEqual(tracker.activity(for: today).hasMeditation, true)
        }
    }
}
