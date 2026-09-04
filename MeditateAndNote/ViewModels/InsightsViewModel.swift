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
            refresh()
        }
    }

    private(set) var insights: [StreakInsight] = []
    private(set) var recommendations: [UserRecommendation] = []
    private(set) var weeklyBreakdown: [WeeklyBucket] = []

    private let manager: any StreakInsightProvidable

    init(manager: any StreakInsightProvidable, initialRange: StreakRange = .last30) {
        self.manager = manager
        self.selectedRange = initialRange
        refresh()
    }

    func refresh() {
        insights = manager.insights(for: selectedRange)
        recommendations = manager.recommendations(for: selectedRange)
        weeklyBreakdown = manager.weeklyBreakdown(for: selectedRange)
    }
}
