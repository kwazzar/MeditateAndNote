//
//  StreakInsight.swift
//  MeditateAndNote
//

import Foundation

// MARK: - Insight Category

enum InsightCategory: Hashable {
    case completion
    case pattern
    case trend
    case risk
}

// MARK: - Weekday Heatmap Data

struct WeekdayHeatmapData: Hashable {
    struct Day: Hashable {
        let name: String
        let shortName: String
        let completionRate: Double
        let totalDays: Int
        let completeDays: Int
        /// Fraction of streak breaks whose first missing day falls on this
        /// weekday. 0 when there are no breaks in the snapshot. Always 0
        /// for range-windowed heatmaps — break pattern is a lifetime metric.
        let breakRate: Double
    }

    let days: [Day]
}

// MARK: - Streak Length Distribution

/// Histogram of how many streaks fell into each length bucket across the
/// whole history. Buckets are fixed (`1 / 2 / 3 / 4-6 / 7-13 / 14+`) so the
/// UI can render a stable chart regardless of history size. Invariants:
/// `sum(buckets.count) == totalStreaks`, and `buckets` always has exactly
/// six entries in the canonical order.
struct StreakLengthDistribution: Hashable {
    struct Bucket: Hashable {
        let range: ClosedRange<Int>
        let label: String
        let count: Int

        func contains(_ length: Int) -> Bool {
            range.contains(length)
        }
    }

    static let canonicalBuckets: [ClosedRange<Int>] = [
        1...1, 2...2, 3...3, 4...6, 7...13, 14...Int.max
    ]

    static let canonicalLabels: [String] = [
        "1 day", "2 days", "3 days", "4-6 days", "1-2 weeks", "2+ weeks"
    ]

    let buckets: [Bucket]
    let totalStreaks: Int
    let medianLength: Int
}

// MARK: - Streak Resilience

/// Recovery profile of the streak history. `avgRecoveryDays` is the mean
/// number of non-complete days between the end of one streak and the start
/// of the next. `survivalByDay[n]` is the empirical probability that a
/// streak of length at least `n` survives to length `n+1`. Invariants:
/// `survivalByDay` keys start at 1 and are contiguous; `avgRecoveryDays`
/// is 0 when `totalRecoveries == 0`.
struct StreakResilience: Hashable {
    let avgRecoveryDays: Double
    let longestRecoveryDays: Int
    let totalRecoveries: Int
    let survivalByDay: [Int: Double]
}

// MARK: - Streak Range (value object)

/// Window the user is currently viewing insights over. The engine is
/// range-aware: completion rate, weekly breakdown, and trend insights all
/// re-derive when the range changes. Invariant: `dayCount > 0`.
enum StreakRange: Hashable, CaseIterable, Identifiable {
    case last7
    case last30
    case last90

    var id: Self { self }

    var dayCount: Int {
        switch self {
        case .last7: return 7
        case .last30: return 30
        case .last90: return 90
        }
    }

    var shortLabel: String {
        switch self {
        case .last7: return "7D"
        case .last30: return "30D"
        case .last90: return "90D"
        }
    }

    var title: String {
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
struct WeeklyBucket: Hashable, Identifiable {
    let id: Date
    let weekStart: Date
    let weekEnd: Date
    let totalDays: Int
    let completeDays: Int
    let completionRate: Double

    init(weekStart: Date, weekEnd: Date, totalDays: Int, completeDays: Int) {
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
struct StreakDayDetail: Hashable, Identifiable {
    let date: Date
    let state: CoreDayState
    let meditationTime: Date?
    let noteTime: Date?

    var id: Date { date }
    var isToday: Bool { Calendar.current.isDateInToday(date) }

    /// The single missing action for a partial day, if any. The UI uses
    /// this to render a tappable CTA ("Write a note", "Meditate") without
    /// inspecting the state directly.
    var missingAction: StreakDayDetail.MissingAction? {
        switch state {
        case .empty: return nil
        case .complete: return nil
        case .meditationOnly: return .note
        case .noteOnly: return .meditation
        }
    }

    enum MissingAction: Hashable {
        case meditation
        case note
    }
}

// MARK: - Streak Insight (value object)

struct StreakInsight: Identifiable, Hashable {
    let id = UUID()
    let category: InsightCategory
    let title: String
    let message: String
    let value: Double?
    let icon: String
    var heatmapData: WeekdayHeatmapData?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: StreakInsight, rhs: StreakInsight) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Recommendation Priority

enum RecommendationPriority: Int, Comparable {
    case high = 0
    case medium = 1
    case low = 2

    static func < (lhs: RecommendationPriority, rhs: RecommendationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Recommendation Action

enum RecommendationAction: Hashable {
    case navigateToMeditation
    case navigateToNote
    case setReminder
}

// MARK: - User Recommendation (value object)

struct UserRecommendation: Identifiable, Hashable {
    let id = UUID()
    let priority: RecommendationPriority
    let title: String
    let message: String
    let action: RecommendationAction?
    let icon: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: UserRecommendation, rhs: UserRecommendation) -> Bool {
        lhs.id == rhs.id
    }
}
