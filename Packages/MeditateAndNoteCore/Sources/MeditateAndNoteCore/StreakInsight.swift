//
//  StreakInsight.swift
//  MeditateAndNote
//

import Foundation

// MARK: - Insight Category

public enum InsightCategory: Hashable {
    case completion
    case pattern
    case trend
    case risk
}

// MARK: - Weekday Heatmap Data

public struct WeekdayHeatmapData: Hashable {
    public struct Day: Hashable {
        public let name: String
        public let shortName: String
        public let completionRate: Double
        public let totalDays: Int
        public let completeDays: Int
        /// Fraction of streak breaks whose first missing day falls on this
        /// weekday. 0 when there are no breaks in the snapshot. Always 0
        /// for range-windowed heatmaps — break pattern is a lifetime metric.
        public let breakRate: Double

        public init(
            name: String,
            shortName: String,
            completionRate: Double,
            totalDays: Int,
            completeDays: Int,
            breakRate: Double = 0
        ) {
            self.name = name
            self.shortName = shortName
            self.completionRate = completionRate
            self.totalDays = totalDays
            self.completeDays = completeDays
            self.breakRate = breakRate
        }
    }

    public let days: [Day]

    public init(
        days: [Day]
    ) {
        self.days = days
    }
}

// MARK: - Streak Length Distribution

/// Histogram of how many streaks fell into each length bucket across the
/// whole history. Buckets are fixed (`1 / 2 / 3 / 4-6 / 7-13 / 14+`) so the
/// UI can render a stable chart regardless of history size. Invariants:
/// `sum(buckets.count) == totalStreaks`, and `buckets` always has exactly
/// six entries in the canonical order.
public struct StreakLengthDistribution: Hashable {
    public struct Bucket: Hashable {
        public let range: ClosedRange<Int>
        public let label: String
        public let count: Int

        public init(range: ClosedRange<Int>, label: String, count: Int) {
            self.range = range
            self.label = label
            self.count = count
        }

        func contains(_ length: Int) -> Bool {
            range.contains(length)
        }
    }

    public static let canonicalBuckets: [ClosedRange<Int>] = [
        1...1, 2...2, 3...3, 4...6, 7...13, 14...Int.max
    ]

    public static let canonicalLabels: [String] = [
        "1 day", "2 days", "3 days", "4-6 days", "1-2 weeks", "2+ weeks"
    ]

    public let buckets: [Bucket]
    public let totalStreaks: Int
    public let medianLength: Int

    public init(
        buckets: [Bucket],
        totalStreaks: Int,
        medianLength: Int
    ) {
        self.buckets = buckets
        self.totalStreaks = totalStreaks
        self.medianLength = medianLength
    }
}

// MARK: - Streak Resilience

/// Recovery profile of the streak history. `avgRecoveryDays` is the mean
/// number of non-complete days between the end of one streak and the start
/// of the next. `survivalByDay[n]` is the empirical probability that a
/// streak of length at least `n` survives to length `n+1`. Invariants:
/// `survivalByDay` keys start at 1 and are contiguous; `avgRecoveryDays`
/// is 0 when `totalRecoveries == 0`.
public struct StreakResilience: Hashable {
    public let avgRecoveryDays: Double
    public let longestRecoveryDays: Int
    public let totalRecoveries: Int
    public let survivalByDay: [Int: Double]

    public init(
        avgRecoveryDays: Double,
        longestRecoveryDays: Int,
        totalRecoveries: Int,
        survivalByDay: [Int: Double]
    ) {
        self.avgRecoveryDays = avgRecoveryDays
        self.longestRecoveryDays = longestRecoveryDays
        self.totalRecoveries = totalRecoveries
        self.survivalByDay = survivalByDay
    }
}

// MARK: - Streak Range (value object)

/// Window the user is currently viewing insights over. The engine is
/// range-aware: completion rate, weekly breakdown, and trend insights all
/// re-derive when the range changes. Invariant: `dayCount > 0`.
public enum StreakRange: Hashable, CaseIterable, Identifiable {
    case last7
    case last30
    case last90

    public var id: Self { self }

    public var dayCount: Int {
        switch self {
        case .last7: return 7
        case .last30: return 30
        case .last90: return 90
        }
    }

    public var shortLabel: String {
        switch self {
        case .last7: return "7D"
        case .last30: return "30D"
        case .last90: return "90D"
        }
    }

    public var title: String {
        switch self {
        case .last7: return "Last 7 Days"
        case .last30: return "Last 30 Days"
        case .last90: return "Last 90 Days"
        }
    }
}

// MARK: - Weekly Bucket (value object)

/// One bucket in the weekly drill-down bar graph. Buckets are always
/// week-aligned (Monday→Sunday in the engine's calendar) and `completeDays
/// <= totalDays` by construction.
public struct WeeklyBucket: Hashable, Identifiable {
    public let id: Date
    public let weekStart: Date
    public let weekEnd: Date
    public let totalDays: Int
    public let completeDays: Int
    public let completionRate: Double

    public init(weekStart: Date, weekEnd: Date, totalDays: Int, completeDays: Int) {
        self.id = weekStart
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.totalDays = totalDays
        self.completeDays = completeDays
        self.completionRate = totalDays > 0 ? Double(completeDays) / Double(totalDays) : 0
    }
}

// MARK: - Streak Day Detail (value object)

/// Snapshot of a single calendar day used by the day-detail sheet. Lifted
/// out of `StreakTracker` so the View depends on a pure value object rather
/// than reaching into the engine. `meditationTime` and `noteTime` are
/// optional even when the corresponding flag is true, since the original
/// event timestamp is not always preserved across migrations.
public struct StreakDayDetail: Hashable, Identifiable {
    public let date: Date
    public let state: CoreDayState
    public let meditationTime: Date?
    public let noteTime: Date?

    public var id: Date { date }
    public var isToday: Bool { Calendar.current.isDateInToday(date) }

    /// The single missing action for a partial day, if any. The UI uses
    /// this to render a tappable CTA ("Write a note", "Meditate") without
    /// inspecting the state directly.
    public var missingAction: StreakDayDetail.MissingAction? {
        switch state {
        case .empty: return nil
        case .complete: return nil
        case .meditationOnly: return .note
        case .noteOnly: return .meditation
        }
    }

    public enum MissingAction: Hashable {
        case meditation
        case note
    }

    public init(
        date: Date,
        state: CoreDayState,
        meditationTime: Date? = nil,
        noteTime: Date? = nil
    ) {
        self.date = date
        self.state = state
        self.meditationTime = meditationTime
        self.noteTime = noteTime
    }
}

// MARK: - Streak Snapshot (value object)

/// Point-in-time view of streak state. Produced by `StreakEngine`,
/// persisted via `StreakActivityStore`, consumed by `StreakInsightEngine`.
/// Pure domain — no CoreData / SwiftUI.
public struct StreakSnapshot: Sendable, Codable {
    public let activities: [DailyActivity]
    public let currentStreak: Int
    public let longestStreak: Int
    public let lastCountedDay: Date?

    public init(
        activities: [DailyActivity],
        currentStreak: Int,
        longestStreak: Int,
        lastCountedDay: Date? = nil
    ) {
        self.activities = activities
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCountedDay = lastCountedDay
    }
}

// MARK: - Streak Snapshot Provider (read boundary)

/// Read boundary over streak state. `StreakTracker` conforms trivially;
/// `StreakInsightManager` depends on this instead of the concrete tracker
/// so tests can inject a stub without a real engine.
public protocol StreakSnapshotProvidable {
    var snapshot: StreakSnapshot { get }
}

// MARK: - Streak Insight (value object)

public struct StreakInsight: Identifiable, Hashable {
    public let id: UUID
    public let category: InsightCategory
    public let title: String
    public let message: String
    public let value: Double?
    public let icon: String
    public var heatmapData: WeekdayHeatmapData?

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: StreakInsight, rhs: StreakInsight) -> Bool {
        lhs.id == rhs.id
    }

    public init(
        id: UUID = UUID(),
        category: InsightCategory,
        title: String,
        message: String,
        value: Double? = nil,
        icon: String,
        heatmapData: WeekdayHeatmapData? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.message = message
        self.value = value
        self.icon = icon
        self.heatmapData = heatmapData
    }
}

// MARK: - Recommendation Priority

public enum RecommendationPriority: Int, Comparable {
    case high = 0
    case medium = 1
    case low = 2

    public static func < (lhs: RecommendationPriority, rhs: RecommendationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Recommendation Action

public enum RecommendationAction: Hashable {
    case navigateToMeditation
    case navigateToNote
    case setReminder
}

// MARK: - User Recommendation (value object)

public struct UserRecommendation: Identifiable, Hashable {
    public let id: UUID
    public let priority: RecommendationPriority
    public let title: String
    public let message: String
    public let action: RecommendationAction?
    public let icon: String

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: UserRecommendation, rhs: UserRecommendation) -> Bool {
        lhs.id == rhs.id
    }

    public init(
        id: UUID = UUID(),
        priority: RecommendationPriority,
        title: String,
        message: String,
        action: RecommendationAction? = nil,
        icon: String
    ) {
        self.id = id
        self.priority = priority
        self.title = title
        self.message = message
        self.action = action
        self.icon = icon
    }
}
