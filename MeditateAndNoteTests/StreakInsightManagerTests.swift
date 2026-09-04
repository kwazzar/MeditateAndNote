//
//  StreakInsightManagerTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 04.09.2026.
//

import XCTest
@testable import MeditateAndNote

/// In-memory `StreakActivityStore` double: seeds the tracker's initial
/// snapshot and records every persisted save.
final class SeededStreakStore: StreakActivityStore {
    let seededSnapshot: StreakSnapshot?
    private(set) var savedSnapshots: [StreakSnapshot] = []

    init(seededSnapshot: StreakSnapshot? = nil) {
        self.seededSnapshot = seededSnapshot
    }

    func load() -> StreakSnapshot? { seededSnapshot }
    func save(_ snapshot: StreakSnapshot) async { savedSnapshots.append(snapshot) }
}

final class StreakInsightManagerTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    // MARK: - Helpers

    private func day(_ offset: Int) -> Date {
        calendar.startOfDay(for: Date()).addingTimeInterval(TimeInterval(offset * 86_400))
    }

    /// `count` complete days ending at `endOffset` (0 = today, -1 = yesterday…).
    private func completeRun(count: Int, endOffset: Int = 0) -> [DailyActivity] {
        (0..<count).map { i in
            DailyActivity(date: day(endOffset - i), hasMeditation: true, hasNote: true)
        }
    }

    private func makeManager(activities: [DailyActivity] = [])
        -> (manager: StreakInsightManager, tracker: StreakTracker, store: SeededStreakStore) {
        let snapshot = activities.isEmpty ? nil : StreakSnapshot(
            activities: activities,
            currentStreak: 0,
            longestStreak: 0,
            lastCountedDay: nil
        )
        let store = SeededStreakStore(seededSnapshot: snapshot)
        let tracker = StreakTracker(calendar: calendar, store: store)
        tracker.checkStreakBreak()
        return (StreakInsightManager(streakTracker: tracker), tracker, store)
    }

    // MARK: - Insights generation

    func testInsights_emptyTracker_returnsOnlyCompletionBaselines() {
        let (manager, _, _) = makeManager()

        // The engine always reports the 30-day completion (0% when empty),
        // but a 0% baseline never converts into a recommendation.
        XCTAssertEqual(manager.insights(for: .last30).map(\.title), ["Last 30 Days Completion"])
        XCTAssertTrue(manager.recommendations(for: .last30).isEmpty)
    }

    func testInsights_matchesEngineOutputForTrackerSnapshot() {
        let (manager, tracker, _) = makeManager(activities: completeRun(count: 10))
        let engine = StreakInsightEngine(calendar: calendar)

        let fromManager = manager.insights(for: .last30)
        let direct = engine.generateInsights(from: tracker.snapshot, range: .last30)

        XCTAssertFalse(fromManager.isEmpty, "10 complete days must produce insights")
        XCTAssertEqual(fromManager.count, direct.count)
        XCTAssertEqual(fromManager.map(\.title), direct.map(\.title))
    }

    // MARK: - Caching

    func testInsights_unchangedSnapshot_returnsCachedInstances() {
        let (manager, _, _) = makeManager(activities: completeRun(count: 10))

        let first = manager.insights(for: .last30)
        let second = manager.insights(for: .last30)

        // StreakInsight identity is its UUID: equal ids mean the same
        // cached array, not a freshly generated copy.
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testInsights_afterSnapshotChange_regenerates() async {
        let (manager, tracker, _) = makeManager(activities: completeRun(count: 5))
        let before = manager.insights(for: .last30)

        await tracker.markNoteCreated(date: day(-20))
        let after = manager.insights(for: .last30)

        XCTAssertNotEqual(before.map(\.id), after.map(\.id),
                          "a changed snapshot must invalidate the cache")
    }

    func testInsights_changingRange_returnsNewInstances() {
        let (manager, _, _) = makeManager(activities: completeRun(count: 10))

        let for7 = manager.insights(for: .last7)
        let for30 = manager.insights(for: .last30)

        XCTAssertNotEqual(for7.map(\.title), for30.map(\.title),
                          "different ranges must produce different insight sets")
    }

    func testRecommendations_unchangedSnapshot_returnsCachedInstances() {
        let (manager, _, _) = makeManager(activities: completeRun(count: 10))

        let first = manager.recommendations(for: .last30)
        let second = manager.recommendations(for: .last30)

        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testRecommendations_derivedFromInsightsAndSortedByPriority() {
        // Meditation-only streak: produces a pattern ("Note Gap") and a
        // completion ("Balance") insight, so both medium and low recs exist.
        let skewed = (0..<10).map { DailyActivity(date: day(-$0), hasMeditation: true, hasNote: false) }
        let (manager, _, _) = makeManager(activities: skewed)

        let recommendations = manager.recommendations(for: .last30)

        XCTAssertFalse(recommendations.isEmpty)
        XCTAssertEqual(recommendations, recommendations.sorted { $0.priority < $1.priority },
                       "recommendations must come back priority-sorted")
        XCTAssertTrue(recommendations.contains { $0.title == "Write more notes" })
    }

    func testInvalidateCache_forcesRegenerationWithoutSnapshotChange() {
        let (manager, _, _) = makeManager(activities: completeRun(count: 10))
        let before = manager.insights(for: .last30)

        manager.invalidateCache()
        let after = manager.insights(for: .last30)

        XCTAssertNotEqual(before.map(\.id), after.map(\.id),
                          "invalidateCache must drop memoized insights")
    }
}
