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

    func testCompletionRate_allDaysComplete_last7_100Percent() {
        let sut = makeSUT()
        let activities = (0..<7).map { offset in
            makeActivity(2026, 9, 4 - offset, meditation: true, note: true)
        }
        let snapshot = makeSnapshot(activities: activities)

        let insights = sut.generateInsights(from: snapshot, range: .last7, today: date(2026, 9, 4))
        let rate = insights.first { $0.title == "Last 7 Days Completion" }

        XCTAssertNotNil(rate)
        XCTAssertEqual(rate?.value, 1.0)
    }

    func testCompletionRate_noDaysComplete_last30_0Percent() {
        let sut = makeSUT()
        let activities = (0..<30).map { offset in
            makeActivity(2026, 9, 4 - offset, meditation: false, note: false)
        }
        let snapshot = makeSnapshot(activities: activities)

        let insights = sut.generateInsights(from: snapshot, range: .last30)
        let rate = insights.first { $0.title == "Last 30 Days Completion" }

        XCTAssertNotNil(rate)
        XCTAssertEqual(rate?.value, 0.0)
    }

    func testCompletionRate_halfDaysComplete_last7_roughlyHalf() {
        let sut = makeSUT()
        var activities: [DailyActivity] = []
        for offset in 0..<7 {
            let complete = offset % 2 == 0
            activities.append(makeActivity(2026, 9, 4 - offset,
                                           meditation: complete, note: complete))
        }
        let snapshot = makeSnapshot(activities: activities)

        let insights = sut.generateInsights(from: snapshot, range: .last7, today: date(2026, 9, 4))
        let rate = insights.first { $0.title == "Last 7 Days Completion" }

        XCTAssertNotNil(rate)
        XCTAssertNotNil(rate?.value)
        // 4 out of 7 days complete (offsets 0,2,4,6)
        XCTAssertEqual(rate!.value!, 4.0 / 7.0, accuracy: 0.01)
    }

    func testCompletionRate_last90_usesAll90Days() {
        let sut = makeSUT()
        // 60 complete days out of 90
        let activities = (0..<90).map { offset in
            makeActivity(2026, 9, 4 - offset,
                         meditation: offset < 60,
                         note: offset < 60)
        }
        let snapshot = makeSnapshot(activities: activities)

        let rate = sut.completionRate(in: .last90, snapshot: snapshot, today: date(2026, 9, 4))
        XCTAssertEqual(rate, 60.0 / 90.0, accuracy: 0.001)
    }

    func testCompletionRate_rangeExcludesOlderActivities() {
        let sut = makeSUT()
        // 30 complete days, but the older 25 fall outside the 7-day window.
        let activities = (0..<30).map { offset in
            makeActivity(2026, 9, 4 - offset, meditation: true, note: true)
        }
        let snapshot = makeSnapshot(activities: activities)

        let rate7 = sut.completionRate(in: .last7, snapshot: snapshot, today: date(2026, 9, 4))
        XCTAssertEqual(rate7, 1.0, "the 7 most-recent activities are all complete")
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
        let heatmap = insights.first { $0.title == "Weekly Heatmap" }

        XCTAssertNotNil(heatmap)
        XCTAssertTrue(heatmap?.message.contains("Saturday") ?? false)
        XCTAssertNotNil(heatmap?.heatmapData)
    }

    func testWeakDays_allDaysAboveThreshold_showsHeatmap() {
        let sut = makeSUT()
        var activities: [DailyActivity] = []

        for offset in 0..<28 {
            let d = date(2026, 8, 7 + offset)
            activities.append(DailyActivity(date: d, hasMeditation: true, hasNote: true))
        }

        let snapshot = makeSnapshot(activities: activities)
        let insights = sut.generateInsights(from: snapshot)
        let heatmap = insights.first { $0.title == "Weekly Heatmap" }

        XCTAssertNotNil(heatmap)
        XCTAssertNotNil(heatmap?.heatmapData)
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

        // This half (last 15 days): 5 complete
        for offset in 0..<5 {
            activities.append(makeActivity(2026, 9, 4 - offset, meditation: true, note: true))
        }
        // Previous half (15–29 days back): 2 complete
        for offset in 15..<17 {
            activities.append(makeActivity(2026, 9, 4 - offset, meditation: true, note: true))
        }

        let snapshot = makeSnapshot(activities: activities)
        let insights = sut.generateInsights(from: snapshot, range: .last30)
        let trend = insights.first { $0.title == "30D Trend" }

        XCTAssertNotNil(trend)
        XCTAssertTrue(trend?.icon == "arrow.up.right")
    }

    func testTrend_declining_showsArrowDown() {
        let sut = makeSUT()
        var activities: [DailyActivity] = []

        // This half: 2 complete
        for offset in 0..<2 {
            activities.append(makeActivity(2026, 9, 4 - offset, meditation: true, note: true))
        }
        // Previous half: 5 complete
        for offset in 15..<20 {
            activities.append(makeActivity(2026, 9, 4 - offset, meditation: true, note: true))
        }

        let snapshot = makeSnapshot(activities: activities)
        let insights = sut.generateInsights(from: snapshot, range: .last30)
        let trend = insights.first { $0.title == "30D Trend" }

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

        let insights = sut.generateInsights(from: snapshot, today: date(2026, 9, 4))
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

        let insights = sut.generateInsights(from: snapshot, range: .last30)
        let balance = insights.first { $0.title == "30D Balance" }

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

        let insights = sut.generateInsights(from: snapshot, range: .last30)
        let balance = insights.first { $0.title == "30D Balance" }

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
        let heatmapData = WeekdayHeatmapData(days: [
            .init(name: "Sunday", shortName: "Su", completionRate: 0.1, totalDays: 0, completeDays: 0, breakRate: 0),
            .init(name: "Monday", shortName: "Mo", completionRate: 0.8, totalDays: 0, completeDays: 0, breakRate: 0),
            .init(name: "Tuesday", shortName: "Tu", completionRate: 0.9, totalDays: 0, completeDays: 0, breakRate: 0),
            .init(name: "Wednesday", shortName: "We", completionRate: 0.7, totalDays: 0, completeDays: 0, breakRate: 0),
            .init(name: "Thursday", shortName: "Th", completionRate: 0.6, totalDays: 0, completeDays: 0, breakRate: 0),
            .init(name: "Friday", shortName: "Fr", completionRate: 0.5, totalDays: 0, completeDays: 0, breakRate: 0),
            .init(name: "Saturday", shortName: "Sa", completionRate: 0.3, totalDays: 0, completeDays: 0, breakRate: 0),
        ])
        let insight = StreakInsight(
            category: .pattern,
            title: "Weekly Heatmap",
            message: "Sunday is your weakest day",
            value: nil,
            icon: "calendar",
            heatmapData: heatmapData
        )

        let recs = sut.generateRecommendations(from: [insight])
        XCTAssertEqual(recs.first?.action, .setReminder)
    }

    // MARK: - Range awareness

    func testCompletionRate_last7DayTitle_reflectsRange() {
        let sut = makeSUT()
        let snapshot = makeSnapshot(activities: [])
        let insights = sut.generateInsights(from: snapshot, range: .last7)
        XCTAssertEqual(insights.first?.title, "Last 7 Days Completion")
    }

    func testCompletionRate_last90DayTitle_reflectsRange() {
        let sut = makeSUT()
        let snapshot = makeSnapshot(activities: [])
        let insights = sut.generateInsights(from: snapshot, range: .last90)
        XCTAssertEqual(insights.first?.title, "Last 90 Days Completion")
    }

    func testWeakDay_window7_excludesOlderHistory() {
        let sut = makeSUT()
        var activitiesByDate: [Date: DailyActivity] = [:]

        // Older history: every Saturday in the *previous* month was complete.
        // Without range-filtering, those would inflate Saturday's rate.
        for offset in 0..<28 {
            let d = date(2026, 8, 7 + offset)
            let weekday = calendar.component(.weekday, from: d)
            let complete = weekday == 7
            activitiesByDate[d] = DailyActivity(date: d, hasMeditation: complete, hasNote: complete)
        }
        // Last 7 days (08-29..09-04): complete on every day except Saturday (08-29).
        for offset in 0..<7 {
            let d = date(2026, 9, 4 - offset)
            let weekday = calendar.component(.weekday, from: d)
            let complete = weekday != 7
            activitiesByDate[d] = DailyActivity(date: d, hasMeditation: complete, hasNote: complete)
        }

        let activities = Array(activitiesByDate.values)
        let snapshot = makeSnapshot(activities: activities)
        let heatmap = sut.generateInsights(from: snapshot, range: .last7)
            .first { $0.title == "Weekly Heatmap" }

        XCTAssertNotNil(heatmap?.heatmapData)
        let saturday = heatmap?.heatmapData?.days.first { $0.shortName == "Sa" }
        XCTAssertEqual(saturday?.completionRate ?? 1.0, 0.0, accuracy: 0.01,
                       "the 7-day window must report Saturday's rate from the last 7 days only")
    }

    func testTrendTitle_reflectsRange() {
        let sut = makeSUT()
        let activities = (0..<60).map { offset in
            makeActivity(2026, 9, 4 - offset, meditation: true, note: true)
        }
        let snapshot = makeSnapshot(activities: activities)

        XCTAssertEqual(
            sut.generateInsights(from: snapshot, range: .last7).first { $0.category == .trend }?.title,
            "7D Trend"
        )
        XCTAssertEqual(
            sut.generateInsights(from: snapshot, range: .last30).first { $0.category == .trend }?.title,
            "30D Trend"
        )
        XCTAssertEqual(
            sut.generateInsights(from: snapshot, range: .last90).first { $0.category == .trend }?.title,
            "90D Trend"
        )
    }

    // MARK: - Weekly Breakdown

    func testWeeklyBreakdown_last7_returnsAtLeastOneBucket() {
        let sut = makeSUT()
        let activities = (0..<7).map { offset in
            makeActivity(2026, 9, 4 - offset, meditation: true, note: true)
        }
        let snapshot = makeSnapshot(activities: activities)

        let buckets = sut.weeklyBreakdown(from: snapshot, range: .last7, today: date(2026, 9, 4))

        XCTAssertGreaterThanOrEqual(buckets.count, 1)
        let totalComplete = buckets.reduce(0) { $0 + $1.completeDays }
        XCTAssertEqual(totalComplete, 7, "all 7 complete days must appear in the buckets")
    }

    func testWeeklyBreakdown_last30_alignsByWeek() {
        let sut = makeSUT()
        let snapshot = makeSnapshot(activities: [])

        let buckets = sut.weeklyBreakdown(from: snapshot, range: .last30, today: date(2026, 9, 4))

        // 30 days spans ~5 partial-or-full weeks.
        XCTAssertGreaterThanOrEqual(buckets.count, 4)
        XCTAssertLessThanOrEqual(buckets.count, 6)
    }

    func testWeeklyBreakdown_last90_has13Buckets() {
        let sut = makeSUT()
        let snapshot = makeSnapshot(activities: [])

        let buckets = sut.weeklyBreakdown(from: snapshot, range: .last90, today: date(2026, 9, 4))

        // 90 days / 7 ≈ 13 buckets.
        XCTAssertGreaterThanOrEqual(buckets.count, 12)
        XCTAssertLessThanOrEqual(buckets.count, 14)
    }

    func testWeeklyBreakdown_bucketsAreChronological() {
        let sut = makeSUT()
        let snapshot = makeSnapshot(activities: [])

        let buckets = sut.weeklyBreakdown(from: snapshot, range: .last90, today: date(2026, 9, 4))

        for i in 1..<buckets.count {
            XCTAssertLessThan(buckets[i - 1].weekStart, buckets[i].weekStart,
                              "buckets must be ordered oldest→newest")
        }
    }

    func testWeeklyBreakdown_lastBucketNeverExtendsBeyondToday() {
        let sut = makeSUT()
        let snapshot = makeSnapshot(activities: [])

        let buckets = sut.weeklyBreakdown(from: snapshot, range: .last30, today: date(2026, 9, 4))
        let last = buckets.last

        XCTAssertNotNil(last)
        XCTAssertLessThanOrEqual(last?.weekEnd ?? .distantFuture, date(2026, 9, 4))
    }

    func testWeeklyBreakdown_totalDaysAreWithinRange() {
        let sut = makeSUT()
        let snapshot = makeSnapshot(activities: [])

        let buckets = sut.weeklyBreakdown(from: snapshot, range: .last30, today: date(2026, 9, 4))

        let totalDays = buckets.reduce(0) { $0 + $1.totalDays }
        XCTAssertEqual(totalDays, 30, "all 30 days in the window must be accounted for")
    }

    func testWeeklyBreakdown_completesForCompleteActivities() {
        let sut = makeSUT()
        // 14 complete days, then 14 empty days within a 30-day window.
        var activities: [DailyActivity] = []
        for offset in 0..<14 {
            activities.append(makeActivity(2026, 9, 4 - offset, meditation: true, note: true))
        }
        let snapshot = makeSnapshot(activities: activities)

        let buckets = sut.weeklyBreakdown(from: snapshot, range: .last30, today: date(2026, 9, 4))

        let totalComplete = buckets.reduce(0) { $0 + $1.completeDays }
        XCTAssertEqual(totalComplete, 14)
    }

    func testWeeklyBreakdown_emptyRange_90DayWindow_returnsEmptyWhenNoActivities() {
        let sut = makeSUT()
        let snapshot = makeSnapshot(activities: [])

        let buckets = sut.weeklyBreakdown(from: snapshot, range: .last90, today: date(2026, 9, 4))

        let totalComplete = buckets.reduce(0) { $0 + $1.completeDays }
        XCTAssertEqual(totalComplete, 0)
    }

    // MARK: - Lifetime: streakLengthDistribution

    func testStreakLengthDistribution_emptySnapshot() {
        let sut = makeSUT()
        let snapshot = makeSnapshot(activities: [])

        let distribution = sut.streakLengthDistribution(from: snapshot)

        XCTAssertEqual(distribution.totalStreaks, 0)
        XCTAssertEqual(distribution.medianLength, 0)
        XCTAssertTrue(distribution.buckets.allSatisfy { $0.count == 0 })
    }

    func testStreakLengthDistribution_bucketsRunLengths() {
        let sut = makeSUT()
        // Gaps between runs:
        //   days 1-3   → run length 3
        //   days 5-7   → run length 3
        //   days 10-12 → run length 3
        //   days 15-19 → run length 5
        //   days 22-24 → run length 3
        // Total 5 runs: four 3-day runs and one 5-day run.
        let activities: [DailyActivity] = [
            makeActivity(2026, 1, 1, meditation: true, note: true),
            makeActivity(2026, 1, 2, meditation: true, note: true),
            makeActivity(2026, 1, 3, meditation: true, note: true),
            makeActivity(2026, 1, 5, meditation: true, note: true),
            makeActivity(2026, 1, 6, meditation: true, note: true),
            makeActivity(2026, 1, 7, meditation: true, note: true),
            makeActivity(2026, 1, 10, meditation: true, note: true),
            makeActivity(2026, 1, 11, meditation: true, note: true),
            makeActivity(2026, 1, 12, meditation: true, note: true),
            makeActivity(2026, 1, 15, meditation: true, note: true),
            makeActivity(2026, 1, 16, meditation: true, note: true),
            makeActivity(2026, 1, 17, meditation: true, note: true),
            makeActivity(2026, 1, 18, meditation: true, note: true),
            makeActivity(2026, 1, 19, meditation: true, note: true),
            makeActivity(2026, 1, 22, meditation: true, note: true),
            makeActivity(2026, 1, 23, meditation: true, note: true),
            makeActivity(2026, 1, 24, meditation: true, note: true),
        ]
        let snapshot = makeSnapshot(activities: activities)

        let distribution = sut.streakLengthDistribution(from: snapshot)

        XCTAssertEqual(distribution.totalStreaks, 5)
        XCTAssertEqual(distribution.buckets[0].count, 0) // 1 day
        XCTAssertEqual(distribution.buckets[1].count, 0) // 2 days
        XCTAssertEqual(distribution.buckets[2].count, 4) // 3 days (×4)
        XCTAssertEqual(distribution.buckets[3].count, 1) // 4-6 days (run of 5)
        XCTAssertEqual(distribution.buckets[4].count, 0) // 7-13 days
        XCTAssertEqual(distribution.buckets[5].count, 0) // 14+ days
    }

    func testStreakLengthDistribution_median() {
        let sut = makeSUT()
        // Runs: 1, 5, 10 → median = 5
        let activities: [DailyActivity] = [
            makeActivity(2026, 1, 1, meditation: true, note: true),
            makeActivity(2026, 1, 3, meditation: true, note: true),
            makeActivity(2026, 1, 4, meditation: true, note: true),
            makeActivity(2026, 1, 5, meditation: true, note: true),
            makeActivity(2026, 1, 6, meditation: true, note: true),
            makeActivity(2026, 1, 7, meditation: true, note: true),
            makeActivity(2026, 1, 9, meditation: true, note: true),
            makeActivity(2026, 1, 10, meditation: true, note: true),
            makeActivity(2026, 1, 11, meditation: true, note: true),
            makeActivity(2026, 1, 12, meditation: true, note: true),
            makeActivity(2026, 1, 13, meditation: true, note: true),
            makeActivity(2026, 1, 14, meditation: true, note: true),
            makeActivity(2026, 1, 15, meditation: true, note: true),
            makeActivity(2026, 1, 16, meditation: true, note: true),
            makeActivity(2026, 1, 17, meditation: true, note: true),
            makeActivity(2026, 1, 18, meditation: true, note: true),
        ]
        let snapshot = makeSnapshot(activities: activities)

        let distribution = sut.streakLengthDistribution(from: snapshot)

        XCTAssertEqual(distribution.medianLength, 5)
    }

    // MARK: - Lifetime: resilience

    func testResilience_noRecoveries() {
        let sut = makeSUT()
        let activities = (1...5).map { makeActivity(2026, 1, $0, meditation: true, note: true) }
        let snapshot = makeSnapshot(activities: activities)

        let resilience = sut.resilience(from: snapshot)

        XCTAssertEqual(resilience.totalRecoveries, 0)
        XCTAssertEqual(resilience.avgRecoveryDays, 0)
        XCTAssertEqual(resilience.longestRecoveryDays, 0)
    }

    func testResilience_singleRecovery() {
        let sut = makeSUT()
        // Two runs separated by 3 days: day 1, then day 5
        let activities = [
            makeActivity(2026, 1, 1, meditation: true, note: true),
            makeActivity(2026, 1, 5, meditation: true, note: true),
        ]
        let snapshot = makeSnapshot(activities: activities)

        let resilience = sut.resilience(from: snapshot)

        XCTAssertEqual(resilience.totalRecoveries, 1)
        XCTAssertEqual(resilience.longestRecoveryDays, 4) // 1 → 5 = 4 days apart
        XCTAssertEqual(resilience.avgRecoveryDays, 4, accuracy: 0.001)
    }

    func testResilience_survivalByDay() {
        let sut = makeSUT()
        // Two runs: lengths 1 and 5. P(>=2 | >=1) = 1/2 = 0.5. P(>=5 | >=4) = 1/1 = 1.0.
        let activities = [
            makeActivity(2026, 1, 1, meditation: true, note: true),
            makeActivity(2026, 1, 3, meditation: true, note: true),
            makeActivity(2026, 1, 4, meditation: true, note: true),
            makeActivity(2026, 1, 5, meditation: true, note: true),
            makeActivity(2026, 1, 6, meditation: true, note: true),
            makeActivity(2026, 1, 7, meditation: true, note: true),
        ]
        let snapshot = makeSnapshot(activities: activities)

        let resilience = sut.resilience(from: snapshot)

        XCTAssertEqual(resilience.survivalByDay[1] ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(resilience.survivalByDay[4] ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(resilience.survivalByDay[5] ?? 0, 0.0, accuracy: 0.001)
    }

    // MARK: - Lifetime: weekdayBreakPattern

    func testWeekdayBreakPattern_empty() {
        let sut = makeSUT()
        let snapshot = makeSnapshot(activities: [])

        let pattern = sut.weekdayBreakPattern(from: snapshot)

        XCTAssertTrue(pattern.isEmpty)
    }

    func testWeekdayBreakPattern_countsFirstMissingWeekday() {
        let sut = makeSUT()
        // Run 1: days 3-4 (Sat-Sun), gap, day 5 (Mon) has no activity → break weekday = Mon
        // Run 2: days 9-10 (Fri-Sat), day 11 (Sun) is incomplete → break weekday = Sun
        // Total 2 breaks: Monday and Sunday, each at 0.5.
        let activities: [DailyActivity] = [
            makeActivity(2026, 1, 3, meditation: true, note: true),
            makeActivity(2026, 1, 4, meditation: true, note: true),
            makeActivity(2026, 1, 9, meditation: true, note: true),
            makeActivity(2026, 1, 10, meditation: true, note: true),
            makeActivity(2026, 1, 11, meditation: true, note: false),
        ]
        let snapshot = makeSnapshot(activities: activities)

        let pattern = sut.weekdayBreakPattern(from: snapshot)

        XCTAssertEqual(pattern[2] ?? 0, 0.5, accuracy: 0.001) // Monday
        XCTAssertEqual(pattern[1] ?? 0, 0.5, accuracy: 0.001) // Sunday
        XCTAssertNil(pattern[3])
    }
}
