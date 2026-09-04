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

    private var cachedInsights: [StreakInsight]?
    private var cachedRecommendations: [UserRecommendation]?
    private var lastSnapshotSignature: Int?

    init(streakTracker: StreakTracker) {
        self.streakTracker = streakTracker
    }

    func insights() -> [StreakInsight] {
        let signature = snapshotSignature(streakTracker.snapshot)
        if signature == lastSnapshotSignature, let cached = cachedInsights {
            return cached
        }
        let result = engine.generateInsights(from: streakTracker.snapshot)
        cachedInsights = result
        lastSnapshotSignature = signature
        return result
    }

    func recommendations() -> [UserRecommendation] {
        let signature = snapshotSignature(streakTracker.snapshot)
        if signature == lastSnapshotSignature, let cached = cachedRecommendations {
            return cached
        }
        let currentInsights = insights()
        let result = engine.generateRecommendations(from: currentInsights)
        cachedRecommendations = result
        return result
    }

    func invalidateCache() {
        cachedInsights = nil
        cachedRecommendations = nil
        lastSnapshotSignature = nil
    }

    private func snapshotSignature(_ snapshot: StreakSnapshot) -> Int {
        var hasher = Hasher()
        hasher.combine(snapshot.activities.count)
        hasher.combine(snapshot.currentStreak)
        hasher.combine(snapshot.longestStreak)
        hasher.combine(snapshot.lastCountedDay)
        for activity in snapshot.activities.sorted(by: { $0.date < $1.date }) {
            hasher.combine(activity.date)
            hasher.combine(activity.hasMeditation)
            hasher.combine(activity.hasNote)
        }
        return hasher.finalize()
    }
}
