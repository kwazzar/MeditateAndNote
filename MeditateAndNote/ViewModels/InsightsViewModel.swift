//
//  InsightsViewModel.swift
//  MeditateAndNote
//

import Foundation

@Observable
final class InsightsViewModel {
    var selectedRange: StreakRange {
        didSet {
            guard oldValue != selectedRange else { return }
            refreshRangeAware()
        }
    }

    private(set) var insights: [StreakInsight] = []
    private(set) var recommendations: [UserRecommendation] = []
    private(set) var weeklyBreakdown: [WeeklyBucket] = []

    private(set) var streakLengthDistribution: StreakLengthDistribution = .init(
        buckets: [],
        totalStreaks: 0,
        medianLength: 0
    )
    private(set) var resilience: StreakResilience = .init(
        avgRecoveryDays: 0,
        longestRecoveryDays: 0,
        totalRecoveries: 0,
        survivalByDay: [:]
    )
    private(set) var weekdayBreakPattern: [Int: Double] = [:]
    private(set) var weekdayBreakHeatmap: WeekdayHeatmapData = .init(days: [])

    private let manager: any StreakInsightProvidable

    init(manager: any StreakInsightProvidable, initialRange: StreakRange = .last30) {
        self.manager = manager
        self.selectedRange = initialRange
        refresh()
    }

    func refresh() {
        refreshRangeAware()
        refreshLifetime()
    }

    private func refreshRangeAware() {
        insights = manager.insights(for: selectedRange)
        recommendations = manager.recommendations(for: selectedRange)
        weeklyBreakdown = manager.weeklyBreakdown(for: selectedRange)
    }

    private func refreshLifetime() {
        streakLengthDistribution = manager.streakLengthDistribution()
        resilience = manager.resilience()
        weekdayBreakPattern = manager.weekdayBreakPattern()
        weekdayBreakHeatmap = manager.weekdayBreakHeatmap()
    }
}
