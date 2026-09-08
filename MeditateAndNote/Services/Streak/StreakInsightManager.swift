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

    func streakLengthDistribution() -> StreakLengthDistribution
    func resilience() -> StreakResilience
    func weekdayBreakPattern() -> [Int: Double]
    func weekdayBreakHeatmap() -> WeekdayHeatmapData
}

// MARK: - Streak Insight Manager

final class StreakInsightManager: StreakInsightProvidable {
    private let snapshotProvider: any StreakSnapshotProvidable
    private let engine = StreakInsightEngine()

    private struct CacheKey: Hashable {
        let range: StreakRange
        let signature: Int
    }

    private var cachedInsights: [CacheKey: [StreakInsight]] = [:]
    private var cachedRecommendations: [CacheKey: [UserRecommendation]] = [:]
    private var cachedDistribution: [Int: StreakLengthDistribution] = [:]
    private var cachedResilience: [Int: StreakResilience] = [:]
    private var cachedBreakPattern: [Int: [Int: Double]] = [:]
    private var cachedBreakHeatmap: [Int: WeekdayHeatmapData] = [:]
    private var lastSnapshotSignature: Int?

    init(snapshotProvider: any StreakSnapshotProvidable) {
        self.snapshotProvider = snapshotProvider
    }

    /// Backwards-compatible initializer for existing call sites and tests.
    convenience init(streakTracker: StreakTracker) {
        self.init(snapshotProvider: streakTracker as any StreakSnapshotProvidable)
    }

    func insights(for range: StreakRange) -> [StreakInsight] {
        let key = cacheKey(for: range)
        if let cached = cachedInsights[key] {
            return cached
        }
        let result = engine.generateInsights(from: snapshotProvider.snapshot, range: range)
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
        engine.weeklyBreakdown(from: snapshotProvider.snapshot, range: range)
    }

    func streakLengthDistribution() -> StreakLengthDistribution {
        let signature = currentSnapshotSignature()
        if let cached = cachedDistribution[signature] {
            return cached
        }
        let result = engine.streakLengthDistribution(from: snapshotProvider.snapshot)
        cachedDistribution[signature] = result
        return result
    }

    func resilience() -> StreakResilience {
        let signature = currentSnapshotSignature()
        if let cached = cachedResilience[signature] {
            return cached
        }
        let result = engine.resilience(from: snapshotProvider.snapshot)
        cachedResilience[signature] = result
        return result
    }

    func weekdayBreakPattern() -> [Int: Double] {
        let signature = currentSnapshotSignature()
        if let cached = cachedBreakPattern[signature] {
            return cached
        }
        let result = engine.weekdayBreakPattern(from: snapshotProvider.snapshot)
        cachedBreakPattern[signature] = result
        return result
    }

    func weekdayBreakHeatmap() -> WeekdayHeatmapData {
        let signature = currentSnapshotSignature()
        if let cached = cachedBreakHeatmap[signature] {
            return cached
        }
        let result = engine.weekdayBreakHeatmapData(from: snapshotProvider.snapshot)
        cachedBreakHeatmap[signature] = result
        return result
    }

    func invalidateCache() {
        cachedInsights.removeAll()
        cachedRecommendations.removeAll()
        cachedDistribution.removeAll()
        cachedResilience.removeAll()
        cachedBreakPattern.removeAll()
        cachedBreakHeatmap.removeAll()
        lastSnapshotSignature = nil
    }

    // MARK: - Domain Event Subscription

    /// Exhaustive switch: snapshot-mutating events drop memoized results.
    /// The per-(range, signature) cache already regenerates on signature
    /// change; explicit invalidation frees stale entries eagerly.
    func handle(_ event: DomainEvent) {
        switch event {
        case .noteCreated, .meditationCompleted:
            invalidateCache()
        case .noteUpdated, .noteDeleted, .aiDraftGenerated, .aiDraftMetric:
            break
        }
    }

    private func cacheKey(for range: StreakRange) -> CacheKey {
        CacheKey(range: range, signature: currentSnapshotSignature())
    }

    private func currentSnapshotSignature() -> Int {
        let signature = snapshotSignature(snapshotProvider.snapshot)
        lastSnapshotSignature = signature
        return signature
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
