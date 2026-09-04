//
//  StreakInsightEngine.swift
//  MeditateAndNote
//
//  Pure domain logic: generates insights and recommendations from streak data.
//  No CoreData, SwiftUI, or infrastructure dependencies.
//

import Foundation

struct StreakInsightEngine {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: - Public API

    func generateInsights(from snapshot: StreakSnapshot) -> [StreakInsight] {
        var insights: [StreakInsight] = []
        let today = calendar.startOfDay(for: Date())

        insights.append(contentsOf: completionRateInsights(snapshot: snapshot, today: today))
        insights.append(contentsOf: weakDayInsights(snapshot: snapshot))
        insights.append(contentsOf: partialDayInsights(snapshot: snapshot))
        insights.append(contentsOf: timeOfDayInsights(snapshot: snapshot))
        insights.append(contentsOf: trendInsights(snapshot: snapshot, today: today))
        insights.append(contentsOf: streakBreakRiskInsight(snapshot: snapshot, today: today))
        insights.append(contentsOf: balanceInsights(snapshot: snapshot))
        insights.append(contentsOf: milestoneInsight(snapshot: snapshot))

        return insights
    }

    func generateRecommendations(from insights: [StreakInsight]) -> [UserRecommendation] {
        var recommendations: [UserRecommendation] = []

        for insight in insights {
            switch insight.category {
            case .risk:
                if let rec = recommendationFromRisk(insight) {
                    recommendations.append(rec)
                }
            case .pattern:
                if let rec = recommendationFromPattern(insight) {
                    recommendations.append(rec)
                }
            case .trend:
                if let rec = recommendationFromTrend(insight) {
                    recommendations.append(rec)
                }
            case .completion:
                if let rec = recommendationFromCompletion(insight) {
                    recommendations.append(rec)
                }
            }
        }

        return recommendations.sorted(by: { $0.priority < $1.priority })
    }

    // MARK: - Completion Rate

    private func completionRateInsights(snapshot: StreakSnapshot, today: Date) -> [StreakInsight] {
        var insights: [StreakInsight] = []

        let last7 = completionRate(in: 7, snapshot: snapshot, today: today)
        insights.append(StreakInsight(
            category: .completion,
            title: "7-Day Completion",
            message: "\(Int(last7 * 100))% of the last 7 days were complete",
            value: last7,
            icon: "chart.bar.fill"
        ))

        let last30 = completionRate(in: 30, snapshot: snapshot, today: today)
        insights.append(StreakInsight(
            category: .completion,
            title: "30-Day Completion",
            message: "\(Int(last30 * 100))% of the last 30 days were complete",
            value: last30,
            icon: "chart.bar.fill"
        ))

        return insights
    }

    private func completionRate(in days: Int, snapshot: StreakSnapshot, today: Date) -> Double {
        let activities = snapshot.activities
        var completeCount = 0
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = calendar.startOfDay(for: date)
            if let activity = activities.first(where: { calendar.isDate($0.date, inSameDayAs: key) }),
               activity.isComplete {
                completeCount += 1
            }
        }
        return Double(completeCount) / Double(days)
    }

    // MARK: - Weak Days

    private func weakDayInsights(snapshot: StreakSnapshot) -> [StreakInsight] {
        let weekdayStats = weekdayCompletionStats(snapshot: snapshot)
        guard !weekdayStats.isEmpty else { return [] }

        let sorted = weekdayStats.sorted { $0.value < $1.value }
        guard let weakest = sorted.first, weakest.value < 0.5 else { return [] }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        let dayName = formatter.weekdaySymbols[weakest.key - 1]

        return [StreakInsight(
            category: .pattern,
            title: "Weak Day",
            message: "\(dayName) — \(Int(weakest.value * 100))% completion rate",
            value: weakest.value,
            icon: "calendar.badge.exclamationmark"
        )]
    }

    private func weekdayCompletionStats(snapshot: StreakSnapshot) -> [Int: Double] {
        var totals: [Int: Int] = [:]
        var completes: [Int: Int] = [:]

        for activity in snapshot.activities {
            let weekday = calendar.component(.weekday, from: activity.date)
            totals[weekday, default: 0] += 1
            if activity.isComplete {
                completes[weekday, default: 0] += 1
            }
        }

        var result: [Int: Double] = [:]
        for (day, total) in totals {
            let complete = completes[day] ?? 0
            result[day] = Double(complete) / Double(total)
        }
        return result
    }

    // MARK: - Partial Day Pattern

    private func partialDayInsights(snapshot: StreakSnapshot) -> [StreakInsight] {
        var meditationOnly = 0
        var noteOnly = 0

        for activity in snapshot.activities {
            if activity.hasMeditation && !activity.hasNote {
                meditationOnly += 1
            } else if !activity.hasMeditation && activity.hasNote {
                noteOnly += 1
            }
        }

        let total = meditationOnly + noteOnly
        guard total > 0 else { return [] }

        if meditationOnly > noteOnly {
            return [StreakInsight(
                category: .pattern,
                title: "Note Gap",
                message: "\(meditationOnly) days meditation without a note — write more notes!",
                value: nil,
                icon: "note.text.badge.plus"
            )]
        } else if noteOnly > meditationOnly {
            return [StreakInsight(
                category: .pattern,
                title: "Meditation Gap",
                message: "\(noteOnly) days notes without meditation — try to meditate too!",
                value: nil,
                icon: "brain.head.profile"
            )]
        }

        return []
    }

    // MARK: - Time of Day

    private func timeOfDayInsights(snapshot: StreakSnapshot) -> [StreakInsight] {
        var meditationHours: [Int] = []
        var noteHours: [Int] = []

        for activity in snapshot.activities {
            if let time = activity.meditationTime {
                meditationHours.append(calendar.component(.hour, from: time))
            }
            if let time = activity.noteTime {
                noteHours.append(calendar.component(.hour, from: time))
            }
        }

        var insights: [StreakInsight] = []

        if let dominantHour = mode(meditationHours) {
            let label = formatHour(dominantHour)
            insights.append(StreakInsight(
                category: .pattern,
                title: "Meditation Time",
                message: "You usually meditate around \(label)",
                value: nil,
                icon: "clock.fill"
            ))
        }

        if let dominantHour = mode(noteHours) {
            let label = formatHour(dominantHour)
            insights.append(StreakInsight(
                category: .pattern,
                title: "Note Time",
                message: "You usually write notes around \(label)",
                value: nil,
                icon: "note.text"
            ))
        }

        return insights
    }

    // MARK: - Trend

    private func trendInsights(snapshot: StreakSnapshot, today: Date) -> [StreakInsight] {
        guard !snapshot.activities.isEmpty else { return [] }

        let thisWeek = completeDaysCount(in: 7, snapshot: snapshot, today: today)
        let lastWeek = completeDaysCount(in: 7, snapshot: snapshot,
                                         today: calendar.date(byAdding: .day, value: -7, to: today) ?? today)

        let diff = thisWeek - lastWeek
        let trend: String
        let icon: String
        if diff > 0 {
            trend = "↑ +\(diff) from last week"
            icon = "arrow.up.right"
        } else if diff < 0 {
            trend = "↓ \(diff) from last week"
            icon = "arrow.down.right"
        } else {
            trend = "→ Same as last week"
            icon = "arrow.right"
        }

        return [StreakInsight(
            category: .trend,
            title: "Weekly Trend",
            message: "\(thisWeek)/7 this week — \(trend)",
            value: Double(thisWeek) / 7.0,
            icon: icon
        )]
    }

    private func completeDaysCount(in days: Int, snapshot: StreakSnapshot, today: Date) -> Int {
        var count = 0
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = calendar.startOfDay(for: date)
            if let activity = snapshot.activities.first(where: { calendar.isDate($0.date, inSameDayAs: key) }),
               activity.isComplete {
                count += 1
            }
        }
        return count
    }

    // MARK: - Streak Break Risk

    private func streakBreakRiskInsight(snapshot: StreakSnapshot, today: Date) -> [StreakInsight] {
        guard snapshot.currentStreak > 0 else { return [] }

        let todayActivity = snapshot.activities.first(where: { calendar.isDate($0.date, inSameDayAs: today) })
        let todayComplete = todayActivity?.isComplete ?? false

        if !todayComplete {
            return [StreakInsight(
                category: .risk,
                title: "Streak at Risk!",
                message: "Complete today to keep your \(snapshot.currentStreak)-day streak alive",
                value: nil,
                icon: "exclamationmark.triangle.fill"
            )]
        }

        return []
    }

    // MARK: - Balance

    private func balanceInsights(snapshot: StreakSnapshot) -> [StreakInsight] {
        let totalDays = snapshot.activities.count
        guard totalDays > 0 else { return [] }

        let meditationDays = snapshot.activities.filter(\.hasMeditation).count
        let noteDays = snapshot.activities.filter(\.hasNote).count

        let meditationRatio = Double(meditationDays) / Double(totalDays)
        let noteRatio = Double(noteDays) / Double(totalDays)

        let diff = abs(meditationRatio - noteRatio)
        guard diff > 0.15 else { return [] }

        let message: String
        if meditationRatio > noteRatio {
            message = "Meditation \(Int(meditationRatio * 100))% vs Notes \(Int(noteRatio * 100))% — write more notes"
        } else {
            message = "Notes \(Int(noteRatio * 100))% vs Meditation \(Int(meditationRatio * 100))% — meditate more"
        }

        return [StreakInsight(
            category: .completion,
            title: "Balance",
            message: message,
            value: noteRatio,
            icon: "scalemass.fill"
        )]
    }

    // MARK: - Milestone

    private func milestoneInsight(snapshot: StreakSnapshot) -> [StreakInsight] {
        let current = snapshot.currentStreak
        let best = snapshot.longestStreak

        guard current > 0, current >= best - 2, current < best else { return [] }

        let remaining = best - current
        return [StreakInsight(
            category: .trend,
            title: "Near Record!",
            message: "\(remaining) days away from your personal best (\(best))",
            value: Double(current) / Double(best),
            icon: "trophy.fill"
        )]
    }

    // MARK: - Recommendations from Insights

    private func recommendationFromRisk(_ insight: StreakInsight) -> UserRecommendation? {
        guard insight.category == .risk else { return nil }
        return UserRecommendation(
            priority: .high,
            title: "Don't break your streak!",
            message: insight.message,
            action: .navigateToMeditation,
            icon: "flame.fill"
        )
    }

    private func recommendationFromPattern(_ insight: StreakInsight) -> UserRecommendation? {
        switch insight.icon {
        case "calendar.badge.exclamationmark":
            return UserRecommendation(
                priority: .medium,
                title: "Plan ahead for weak days",
                message: "Set a reminder for \(insight.title.lowercased()) to stay consistent",
                action: .setReminder,
                icon: "bell.fill"
            )
        case "note.text.badge.plus":
            return UserRecommendation(
                priority: .medium,
                title: "Write more notes",
                message: insight.message,
                action: .navigateToNote,
                icon: "note.text"
            )
        case "brain.head.profile":
            return UserRecommendation(
                priority: .medium,
                title: "Try to meditate daily",
                message: insight.message,
                action: .navigateToMeditation,
                icon: "brain.head.profile"
            )
        default:
            return nil
        }
    }

    private func recommendationFromTrend(_ insight: StreakInsight) -> UserRecommendation? {
        guard insight.icon == "arrow.down.right" else { return nil }
        return UserRecommendation(
            priority: .low,
            title: "Get back on track",
            message: insight.message,
            action: nil,
            icon: "arrow.counterclockwise"
        )
    }

    private func recommendationFromCompletion(_ insight: StreakInsight) -> UserRecommendation? {
        guard insight.icon == "scalemass.fill" else { return nil }
        return UserRecommendation(
            priority: .low,
            title: "Balance your practice",
            message: insight.message,
            action: nil,
            icon: "scalemass.fill"
        )
    }

    // MARK: - Helpers

    private func mode(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        var counts: [Int: Int] = [:]
        values.forEach { counts[$0, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private func formatHour(_ hour: Int) -> String {
        switch hour {
        case 0..<6: return "early morning"
        case 6..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }
}
