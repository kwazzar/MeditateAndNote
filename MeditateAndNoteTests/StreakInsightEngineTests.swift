//
//  StreakInsightEngineTests.swift
//  MeditateAndNoteTests
//

import XCTest
@testable import MeditateAndNote

final class StreakInsightEngineTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    // MARK: - Helpers

    private func makeSUT() -> StreakInsightEngine {
        StreakInsightEngine(calendar: calendar)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }

    private func makeActivity(_ year: Int, _ month: Int, _ day: Int,
                               meditation: Bool = false, note: Bool = false,
                               meditationTime: Date? = nil, noteTime: Date? = nil) -> DailyActivity {
        DailyActivity(
            date: date(year, month, day),
            hasMeditation: meditation,
            hasNote: note,
            meditationTime: meditationTime,
            noteTime: noteTime
        )
    }

    private func makeSnapshot(activities: [DailyActivity],
                               currentStreak: Int = 0,
                               longestStreak: Int = 0,
                               lastCountedDay: Date? = nil) -> StreakSnapshot {
        StreakSnapshot(
            activities: activities,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastCountedDay: lastCountedDay
        )
    }

    // MARK: - Completion Rate

    func testCompletionRate_allDaysComplete_7Day100Percent() {
        let sut = makeSUT()
        let activities = (0..<7).map { offset in
            makeActivity(2026, 9, 4 - offset, meditation: true, note: true)
        }
        let snapshot = makeSnapshot(activities: activities)

        let insights = sut.generateInsights(from: snapshot)
        let rate7 = insights.first { $0.title == "7-Day Completion" }

        XCTAssertNotNil(rate7)
        XCTAssertEqual(rate7?.value, 1.0)
    }

    func testCompletionRate_noDaysComplete_7Day0Percent() {
        let sut = makeSUT()
        let activities = (0..<7).map { offset in
            makeActivity(2026, 9, 4 - offset, meditation: false, note: false)
        }
        let snapshot = makeSnapshot(activities: activities)

        let insights = sut.generateInsights(from: snapshot)
        let rate7 = insights.first { $0.title == "7-Day Completion" }

        XCTAssertNotNil(rate7)
        XCTAssertEqual(rate7?.value, 0.0)
    }

    func testCompletionRate_halfDaysComplete_7DayRoughlyHalf() {
        let sut = makeSUT()
        var activities: [DailyActivity] = []
        for offset in 0..<7 {
            let complete = offset % 2 == 0
            activities.append(makeActivity(2026, 9, 4 - offset,
                                           meditation: complete, note: complete))
        }
        let snapshot = makeSnapshot(activities: activities)

        let insights = sut.generateInsights(from: snapshot)
        let rate7 = insights.first { $0.title == "7-Day Completion" }

        XCTAssertNotNil(rate7)
        XCTAssertNotNil(rate7?.value)
        // 4 out of 7 days complete (offsets 0,2,4,6)
        XCTAssertEqual(rate7!.value!, 4.0 / 7.0, accuracy: 0.01)
    }

    // MARK: - Weak Days

    func testWeakDays_identifiesWeakestDay() {
        let sut = makeSUT()
        var activities: [DailyActivity] = []

        // Complete all days except Saturday (weekday 7)
        for offset in 0..<28 {
            let d = date(2026, 8, 7 + offset) // Aug 7 = Thursday
            let weekday = calendar.component(.weekday, from: d)
            let complete = weekday != 7 // skip Saturday
            activities.append(DailyActivity(date: d, hasMeditation: complete, hasNote: complete))
        }

        let snapshot = makeSnapshot(activities: activities)
        let insights = sut.generateInsights(from: snapshot)
        let weakDay = insights.first { $0.title == "Weak Day" }

        XCTAssertNotNil(weakDay)
        XCTAssertTrue(weakDay?.message.contains("Saturday") ?? false)
    }

    func testWeakDays_allDaysAboveThreshold_noInsight() {
        let sut = makeSUT()
        var activities: [DailyActivity] = []

        // Complete 60% of every day
        for offset in 0..<28 {
            let d = date(2026, 8, 7 + offset)
            activities.append(DailyActivity(date: d, hasMeditation: true, hasNote: true))
        }

        let snapshot = makeSnapshot(activities: activities)
        let insights = sut.generateInsights(from: snapshot)
        let weakDay = insights.first { $0.title == "Weak Day" }

        XCTAssertNil(weakDay)
    }

    // MARK: - Partial Day Pattern

    func testPartialDays_meditationWithoutNote_showsNoteGap() {
        let sut = makeSUT()
        var activities: [DailyActivity] = []
        for offset in 0..<7 {
            activities.append(makeActivity(2026, 9, 4 - offset, meditation: true, note: false))
        }
        let snapshot = makeSnapshot(activities: activities)

        let insights = sut.generateInsights(from: snapshot)
        let gap = insights.first { $0.title == "Note Gap" }

        XCTAssertNotNil(gap)
        XCTAssertTrue(gap?.message.contains("7") ?? false)
    }

    func testPartialDays_noteWithoutMeditation_showsMeditationGap() {
        let sut = makeSUT()
        var activities: [DailyActivity] = []
        for offset in 0..<5 {
            activities.append(makeActivity(2026, 9, 4 - offset, meditation: false, note: true))
        }
        let snapshot = makeSnapshot(activities: activities)

        let insights = sut.generateInsights(from: snapshot)
        let gap = insights.first { $0.title == "Meditation Gap" }

        XCTAssertNotNil(gap)
    }

    func testPartialDays_balanced_noInsight() {
        let sut = makeSUT()
        var activities: [DailyActivity] = []
        for offset in 0..<6 {
            let meditationOnly = offset % 2 == 0
            activities.append(makeActivity(2026, 9, 4 - offset,
                                           meditation: meditationOnly,
                                           note: !meditationOnly))
        }
        let snapshot = makeSnapshot(activities: activities)

        let insights = sut.generateInsights(from: snapshot)
        let gap = insights.first { $0.title == "Note Gap" || $0.title == "Meditation Gap" }

        XCTAssertNil(gap)
    }

    // MARK: - Time of Day

    func testTimeOfDay_morningMeditation_showsMorning() {
        let sut = makeSUT()
        let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date(2026, 9, 4))!
        let activities = [
            makeActivity(2026, 9, 4, meditation: true, meditationTime: morning),
            makeActivity(2026, 9, 3, meditation: true, meditationTime: morning),
            makeActivity(2026, 9, 2, meditation: true, meditationTime: morning),
        ]
        let snapshot = makeSnapshot(activities: activities)

        let insights = sut.generateInsights(from: snapshot)
        let meditationTime = insights.first { $0.title == "Meditation Time" }

        XCTAssertNotNil(meditationTime)
        XCTAssertTrue(meditationTime?.message.contains("morning") ?? false)
    }

    func testTimeOfDay_eveningNote_showsEvening() {
        let sut = makeSUT()
        let evening = calendar.date(bySettingHour: 20, minute: 30, second: 0, of: date(2026, 9, 4))!
        let activities = [
            makeActivity(2026, 9, 4, note: true, noteTime: evening),
            makeActivity(2026, 9, 3, note: true, noteTime: evening),
        ]
        let snapshot = makeSnapshot(activities: activities)

        let insights = sut.generateInsights(from: snapshot)
        let noteTime = insights.first { $0.title == "Note Time" }

        XCTAssertNotNil(noteTime)
        XCTAssertTrue(noteTime?.message.contains("evening") ?? false)
    }

    func testTimeOfDay_noTimes_noInsight() {
        let sut = makeSUT()
        let activities = [
            makeActivity(2026, 9, 4, meditation: true, note: true),
        ]
        let snapshot = makeSnapshot(activities: activities)

        let insights = sut.generateInsights(from: snapshot)
        let timeInsights = insights.filter { $0.title == "Meditation Time" || $0.title == "Note Time" }

        XCTAssertTrue(timeInsights.isEmpty)
    }

    // MARK: - Trend

    func testTrend_improving_showsArrowUp() {
        let sut = makeSUT()
        var activities: [DailyActivity] = []

        // This week: 5 complete
        for offset in 0..<5 {
            activities.append(makeActivity(2026, 9, 4 - offset, meditation: true, note: true))
        }
        // Last week: 2 complete
        for offset in 7..<9 {
            activities.append(makeActivity(2026, 9, 4 - offset, meditation: true, note: true))
        }

        let snapshot = makeSnapshot(activities: activities)
        let insights = sut.generateInsights(from: snapshot)
        let trend = insights.first { $0.title == "Weekly Trend" }

        XCTAssertNotNil(trend)
        XCTAssertTrue(trend?.icon == "arrow.up.right")
    }

    func testTrend_declining_showsArrowDown() {
        let sut = makeSUT()
        var activities: [DailyActivity] = []

        // This week: 2 complete
        for offset in 0..<2 {
            activities.append(makeActivity(2026, 9, 4 - offset, meditation: true, note: true))
        }
        // Last week: 5 complete
        for offset in 7..<12 {
            activities.append(makeActivity(2026, 9, 4 - offset, meditation: true, note: true))
        }

        let snapshot = makeSnapshot(activities: activities)
        let insights = sut.generateInsights(from: snapshot)
        let trend = insights.first { $0.title == "Weekly Trend" }

        XCTAssertNotNil(trend)
        XCTAssertTrue(trend?.icon == "arrow.down.right")
    }

    // MARK: - Streak Break Risk

    func testStreakBreakRisk_activeStreakTodayIncomplete_showsRisk() {
        let sut = makeSUT()
        let activities = [
            makeActivity(2026, 9, 4, meditation: false, note: false),
        ]
        let snapshot = makeSnapshot(activities: activities, currentStreak: 5, longestStreak: 10)

        let insights = sut.generateInsights(from: snapshot)
        let risk = insights.first { $0.title == "Streak at Risk!" }

        XCTAssertNotNil(risk)
        XCTAssertTrue(risk?.category == .risk)
    }

    func testStreakBreakRisk_noStreak_noRisk() {
        let sut = makeSUT()
        let activities = [
            makeActivity(2026, 9, 4, meditation: false, note: false),
        ]
        let snapshot = makeSnapshot(activities: activities, currentStreak: 0)

        let insights = sut.generateInsights(from: snapshot)
        let risk = insights.first { $0.title == "Streak at Risk!" }

        XCTAssertNil(risk)
    }

    func testStreakBreakRisk_todayComplete_noRisk() {
        let sut = makeSUT()
        let activities = [
            makeActivity(2026, 9, 4, meditation: true, note: true),
        ]
        let snapshot = makeSnapshot(activities: activities, currentStreak: 5)

        let insights = sut.generateInsights(from: snapshot)
        let risk = insights.first { $0.title == "Streak at Risk!" }

        XCTAssertNil(risk)
    }

    // MARK: - Balance

    func testBalance_meditationHigher_showsNoteGap() {
        let sut = makeSUT()
        var activities: [DailyActivity] = []
        for offset in 0..<10 {
            activities.append(makeActivity(2026, 9, 4 - offset, meditation: true, note: offset > 3))
        }
        let snapshot = makeSnapshot(activities: activities)

        let insights = sut.generateInsights(from: snapshot)
        let balance = insights.first { $0.title == "Balance" }

        XCTAssertNotNil(balance)
        XCTAssertTrue(balance?.message.contains("Notes") ?? false)
    }

    func testBalance_balanced_noInsight() {
        let sut = makeSUT()
        var activities: [DailyActivity] = []
        for offset in 0..<10 {
            activities.append(makeActivity(2026, 9, 4 - offset, meditation: true, note: true))
        }
        let snapshot = makeSnapshot(activities: activities)

        let insights = sut.generateInsights(from: snapshot)
        let balance = insights.first { $0.title == "Balance" }

        XCTAssertNil(balance)
    }

    // MARK: - Milestone

    func testMilestone_nearRecord_showsMilestone() {
        let sut = makeSUT()
        let activities = (0..<8).map { offset in
            makeActivity(2026, 9, 4 - offset, meditation: true, note: true)
        }
        let snapshot = makeSnapshot(activities: activities, currentStreak: 8, longestStreak: 10)

        let insights = sut.generateInsights(from: snapshot)
        let milestone = insights.first { $0.title == "Near Record!" }

        XCTAssertNotNil(milestone)
        XCTAssertTrue(milestone?.message.contains("2") ?? false)
    }

    func testMilestone_atRecord_noMilestone() {
        let sut = makeSUT()
        let activities = (0..<10).map { offset in
            makeActivity(2026, 9, 4 - offset, meditation: true, note: true)
        }
        let snapshot = makeSnapshot(activities: activities, currentStreak: 10, longestStreak: 10)

        let insights = sut.generateInsights(from: snapshot)
        let milestone = insights.first { $0.title == "Near Record!" }

        XCTAssertNil(milestone)
    }

    // MARK: - Recommendations

    func testRecommendations_riskGeneratesHighPriority() {
        let sut = makeSUT()
        let activities = [
            makeActivity(2026, 9, 4, meditation: false, note: false),
        ]
        let snapshot = makeSnapshot(activities: activities, currentStreak: 3)

        let insights = sut.generateInsights(from: snapshot)
        let recs = sut.generateRecommendations(from: insights)

        let riskRec = recs.first { $0.title == "Don't break your streak!" }
        XCTAssertNotNil(riskRec)
        XCTAssertEqual(riskRec?.priority, .high)
    }

    func testRecommendations_sortedByPriority() {
        let sut = makeSUT()
        let activities = (0..<7).map { offset in
            makeActivity(2026, 9, 4 - offset, meditation: true, note: false)
        }
        let snapshot = makeSnapshot(activities: activities, currentStreak: 3)

        let insights = sut.generateInsights(from: snapshot)
        let recs = sut.generateRecommendations(from: insights)

        for i in 1..<recs.count {
            XCTAssertLessThanOrEqual(recs[i - 1].priority.rawValue, recs[i].priority.rawValue)
        }
    }

    // MARK: - Empty Data

    func testEmptySnapshot_noInsights() {
        let sut = makeSUT()
        let snapshot = makeSnapshot(activities: [])

        let insights = sut.generateInsights(from: snapshot)
        // Should still produce completion rate insights (0%)
        let nonCompletion = insights.filter { $0.category != .completion }
        XCTAssertTrue(nonCompletion.isEmpty)
    }

    // MARK: - Recommendations Actions

    func testRecommendationAction_navigateToMeditation() {
        let sut = makeSUT()
        let insight = StreakInsight(
            category: .risk,
            title: "Streak at Risk!",
            message: "Complete today",
            value: nil,
            icon: "exclamationmark.triangle.fill"
        )

        let recs = sut.generateRecommendations(from: [insight])
        XCTAssertEqual(recs.first?.action, .navigateToMeditation)
    }

    func testRecommendationAction_navigateToNote() {
        let sut = makeSUT()
        let insight = StreakInsight(
            category: .pattern,
            title: "Note Gap",
            message: "5 days meditation without a note",
            value: nil,
            icon: "note.text.badge.plus"
        )

        let recs = sut.generateRecommendations(from: [insight])
        XCTAssertEqual(recs.first?.action, .navigateToNote)
    }

    func testRecommendationAction_setReminder() {
        let sut = makeSUT()
        let insight = StreakInsight(
            category: .pattern,
            title: "Weak Day",
            message: "Saturday — 20% completion",
            value: 0.2,
            icon: "calendar.badge.exclamationmark"
        )

        let recs = sut.generateRecommendations(from: [insight])
        XCTAssertEqual(recs.first?.action, .setReminder)
    }
}
