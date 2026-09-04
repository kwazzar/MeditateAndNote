//
//  InsightsViewModelTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 04.09.2026.
//

import XCTest
@testable import MeditateAndNote

// MARK: - Test double

private final class StubInsightManager: StreakInsightProvidable {
    var insightsResult: [StreakInsight] = []
    var recommendationsResult: [UserRecommendation] = []
    var weeklyBreakdownResult: [WeeklyBucket] = []
    private(set) var insightsCallCount = 0
    private(set) var recommendationsCallCount = 0
    private(set) var weeklyBreakdownCallCount = 0
    private(set) var lastInsightsRange: StreakRange?
    private(set) var lastRecommendationsRange: StreakRange?
    private(set) var lastWeeklyBreakdownRange: StreakRange?

    func insights(for range: StreakRange) -> [StreakInsight] {
        insightsCallCount += 1
        lastInsightsRange = range
        return insightsResult
    }

    func recommendations(for range: StreakRange) -> [UserRecommendation] {
        recommendationsCallCount += 1
        lastRecommendationsRange = range
        return recommendationsResult
    }

    func weeklyBreakdown(for range: StreakRange) -> [WeeklyBucket] {
        weeklyBreakdownCallCount += 1
        lastWeeklyBreakdownRange = range
        return weeklyBreakdownResult
    }
}

final class InsightsViewModelTests: XCTestCase {

    private func makeInsight(_ category: InsightCategory) -> StreakInsight {
        StreakInsight(category: category, title: "t", message: "m", value: nil, icon: "star")
    }

    private func makeRecommendation(_ priority: RecommendationPriority) -> UserRecommendation {
        UserRecommendation(priority: priority, title: "r", message: "m", action: nil, icon: "bolt")
    }

    func testInit_publishesInsightsFromManager() {
        let manager = StubInsightManager()
        manager.insightsResult = [makeInsight(.completion)]

        let vm = InsightsViewModel(manager: manager)

        XCTAssertEqual(vm.insights, manager.insightsResult)
        XCTAssertEqual(manager.insightsCallCount, 1, "Init must refresh immediately")
    }

    func testInit_publishesRecommendationsFromManager() {
        let manager = StubInsightManager()
        manager.recommendationsResult = [makeRecommendation(.high)]

        let vm = InsightsViewModel(manager: manager)

        XCTAssertEqual(vm.recommendations, manager.recommendationsResult)
        XCTAssertEqual(manager.recommendationsCallCount, 1)
    }

    func testInit_defaultRange_isLast30() {
        let manager = StubInsightManager()
        let vm = InsightsViewModel(manager: manager)

        XCTAssertEqual(vm.selectedRange, .last30)
        XCTAssertEqual(manager.lastInsightsRange, .last30)
    }

    func testInit_initialRange_respected() {
        let manager = StubInsightManager()
        let vm = InsightsViewModel(manager: manager, initialRange: .last7)

        XCTAssertEqual(vm.selectedRange, .last7)
        XCTAssertEqual(manager.lastInsightsRange, .last7)
    }

    func testInit_publishesWeeklyBreakdownFromManager() {
        let manager = StubInsightManager()
        let bucket = WeeklyBucket(
            weekStart: Date(timeIntervalSince1970: 0),
            weekEnd: Date(timeIntervalSince1970: 86_400 * 6),
            totalDays: 7,
            completeDays: 5
        )
        manager.weeklyBreakdownResult = [bucket]

        let vm = InsightsViewModel(manager: manager)

        XCTAssertEqual(vm.weeklyBreakdown.count, 1)
        XCTAssertEqual(vm.weeklyBreakdown.first?.completeDays, 5)
    }

    func testRefresh_reloadsAllCollections() {
        let manager = StubInsightManager()
        manager.insightsResult = [makeInsight(.trend)]
        manager.recommendationsResult = [makeRecommendation(.low)]
        manager.weeklyBreakdownResult = []
        let vm = InsightsViewModel(manager: manager)
        XCTAssertEqual(vm.insights.count, 1)
        XCTAssertEqual(vm.recommendations.count, 1)

        manager.insightsResult = [
            makeInsight(.completion),
            makeInsight(.risk),
        ]
        manager.recommendationsResult = []
        vm.refresh()

        XCTAssertEqual(vm.insights.count, 2)
        XCTAssertTrue(vm.recommendations.isEmpty)
        XCTAssertEqual(manager.insightsCallCount, 2)
        XCTAssertEqual(manager.recommendationsCallCount, 2)
    }

    func testEmptyManager_yieldsEmptyState() {
        let vm = InsightsViewModel(manager: StubInsightManager())

        XCTAssertTrue(vm.insights.isEmpty)
        XCTAssertTrue(vm.recommendations.isEmpty)
        XCTAssertTrue(vm.weeklyBreakdown.isEmpty)
    }

    func testRefresh_preservesPublishedOrder() {
        let manager = StubInsightManager()
        let first = makeInsight(.completion)
        let second = makeInsight(.pattern)
        manager.insightsResult = [first, second]
        let vm = InsightsViewModel(manager: manager)

        XCTAssertEqual(vm.insights, [first, second])
    }

    func testChangingRange_refreshesInsights() {
        let manager = StubInsightManager()
        let vm = InsightsViewModel(manager: manager, initialRange: .last7)
        XCTAssertEqual(manager.lastInsightsRange, .last7)

        vm.selectedRange = .last90

        XCTAssertEqual(manager.lastInsightsRange, .last90)
        XCTAssertGreaterThan(manager.insightsCallCount, 1,
                             "setting a new range must trigger refresh()")
    }

    func testChangingRange_refreshesRecommendations() {
        let manager = StubInsightManager()
        let vm = InsightsViewModel(manager: manager, initialRange: .last7)
        XCTAssertEqual(manager.lastRecommendationsRange, .last7)

        vm.selectedRange = .last90

        XCTAssertEqual(manager.lastRecommendationsRange, .last90)
    }

    func testChangingRange_refreshesWeeklyBreakdown() {
        let manager = StubInsightManager()
        let vm = InsightsViewModel(manager: manager, initialRange: .last30)
        XCTAssertEqual(manager.lastWeeklyBreakdownRange, .last30)

        vm.selectedRange = .last90

        XCTAssertEqual(manager.lastWeeklyBreakdownRange, .last90)
    }

    func testSettingSameRange_doesNotTriggerRefresh() {
        let manager = StubInsightManager()
        let vm = InsightsViewModel(manager: manager, initialRange: .last30)
        let before = manager.insightsCallCount

        vm.selectedRange = .last30

        XCTAssertEqual(manager.insightsCallCount, before,
                       "setting the same range is a no-op")
    }
}