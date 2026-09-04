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
    private(set) var insightsCallCount = 0
    private(set) var recommendationsCallCount = 0

    func insights() -> [StreakInsight] {
        insightsCallCount += 1
        return insightsResult
    }

    func recommendations() -> [UserRecommendation] {
        recommendationsCallCount += 1
        return recommendationsResult
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

    func testRefresh_reloadsBothCollections() {
        let manager = StubInsightManager()
        manager.insightsResult = [makeInsight(.trend)]
        manager.recommendationsResult = [makeRecommendation(.low)]
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
    }

    func testRefresh_preservesPublishedOrder() {
        let manager = StubInsightManager()
        let first = makeInsight(.completion)
        let second = makeInsight(.pattern)
        manager.insightsResult = [first, second]
        let vm = InsightsViewModel(manager: manager)

        XCTAssertEqual(vm.insights, [first, second])
    }
}