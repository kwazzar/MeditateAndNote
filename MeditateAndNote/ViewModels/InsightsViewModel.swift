//
//  InsightsViewModel.swift
//  MeditateAndNote
//

import Foundation

@Observable
final class InsightsViewModel {
    private(set) var insights: [StreakInsight] = []
    private(set) var recommendations: [UserRecommendation] = []
    private let manager: any StreakInsightProvidable

    init(manager: any StreakInsightProvidable) {
        self.manager = manager
        refresh()
    }

    func refresh() {
        insights = manager.insights()
        recommendations = manager.recommendations()
    }
}
