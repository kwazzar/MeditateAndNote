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
    }

    let days: [Day]
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
