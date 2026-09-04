//
//  StreakInsightManager.swift
//  MeditateAndNote
//
//  Application Service: generates insights from streak data.
//

import Foundation

// MARK: - Protocol for ViewModels

protocol StreakInsightProvidable {
    func insights() -> [StreakInsight]
    func recommendations() -> [UserRecommendation]
}

// MARK: - Streak Insight Manager

final class StreakInsightManager: StreakInsightProvidable {
    private let streakTracker: StreakTracker
    private let engine = StreakInsightEngine()

    init(streakTracker: StreakTracker) {
        self.streakTracker = streakTracker
    }

    func insights() -> [StreakInsight] {
        engine.generateInsights(from: streakTracker.snapshot)
    }

    func recommendations() -> [UserRecommendation] {
        let currentInsights = insights()
        return engine.generateRecommendations(from: currentInsights)
    }
}
