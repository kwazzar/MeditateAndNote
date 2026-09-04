//
//  StreakInsightManager.swift
//  MeditateAndNote
//
//  Application Service: generates insights from streak data.
//

import Foundation

// MARK: - Protocol for ViewModels

protocol StreakInsightProvidable {
    func insights(for range: StreakRange) -> [StreakInsight]
    func recommendations(for range: StreakRange) -> [UserRecommendation]
    func weeklyBreakdown(for range: StreakRange) -> [WeeklyBucket]
}

// MARK: - Streak Insight Manager

final class StreakInsightManager: StreakInsightProvidable {
    private let streakTracker: StreakTracker
    private let engine = StreakInsightEngine()

    private struct CacheKey: Hashable {
        let range: StreakRange
        let signature: Int
    }

    private var cachedInsights: [CacheKey: [StreakInsight]] = [:]
    private var cachedRecommendations: [CacheKey: [UserRecommendation]] = [:]
    private var lastSnapshotSignature: Int?

    init(streakTracker: StreakTracker) {
        self.streakTracker = streakTracker
    }

    func insights(for range: StreakRange) -> [StreakInsight] {
        let key = cacheKey(for: range)
        if let cached = cachedInsights[key] {
            return cached
        }
        let result = engine.generateInsights(from: streakTracker.snapshot, range: range)
        cachedInsights[key] = result
        return result
    }

    func recommendations(for range: StreakRange) -> [UserRecommendation] {
        let key = cacheKey(for: range)
        if let cached = cachedRecommendations[key] {
            return cached
        }
        let currentInsights = insights(for: range)
        let result = engine.generateRecommendations(from: currentInsights)
        cachedRecommendations[key] = result
        return result
    }

    func weeklyBreakdown(for range: StreakRange) -> [WeeklyBucket] {
        engine.weeklyBreakdown(from: streakTracker.snapshot, range: range)
    }

    func invalidateCache() {
        cachedInsights.removeAll()
        cachedRecommendations.removeAll()
        lastSnapshotSignature = nil
    }

    private func cacheKey(for range: StreakRange) -> CacheKey {
        CacheKey(range: range, signature: snapshotSignature(streakTracker.snapshot))
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
