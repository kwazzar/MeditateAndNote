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

    func generateInsights(from snapshot: StreakSnapshot, range: StreakRange = .last30, today: Date = Date()) -> [StreakInsight] {
        var insights: [StreakInsight] = []
        let today = calendar.startOfDay(for: today)

        insights.append(contentsOf: completionRateInsights(snapshot: snapshot, today: today, range: range))
        insights.append(contentsOf: weakDayInsights(snapshot: snapshot, range: range, today: today))
        insights.append(contentsOf: partialDayInsights(snapshot: snapshot, range: range, today: today))
        insights.append(contentsOf: timeOfDayInsights(snapshot: snapshot, range: range, today: today))
        insights.append(contentsOf: trendInsights(snapshot: snapshot, today: today, range: range))
        insights.append(contentsOf: streakBreakRiskInsight(snapshot: snapshot, today: today))
        insights.append(contentsOf: balanceInsights(snapshot: snapshot, range: range, today: today))
        insights.append(contentsOf: milestoneInsight(snapshot: snapshot))

        return insights
    }

    /// Weekly buckets over the given range, newest bucket last.
    /// Buckets are aligned to the engine's `firstWeekday` and trimmed so the
    /// trailing bucket never extends past `today`.
    func weeklyBreakdown(from snapshot: StreakSnapshot, range: StreakRange, today: Date = Date()) -> [WeeklyBucket] {
        let startDay = calendar.startOfDay(for: today)
        guard let rangeStart = calendar.date(byAdding: .day, value: -(range.dayCount - 1), to: startDay) else {
            return []
        }
        let activitiesByDay = Dictionary(
            snapshot.activities.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { _, next in next }
        )

        // Walk backwards from the start-of-week containing `startDay`, in
        // steps of one week. A week is emitted only if any day in it falls
        // within the [rangeStart, startDay] window — this keeps the trailing
        // partial week, leading partial week, and full middle weeks all
        // represented without extending past the window.
        let firstWeekday = calendar.firstWeekday
        var currentWeekStart = startOfWeek(containing: startDay, firstWeekday: firstWeekday)
        var buckets: [WeeklyBucket] = []

        while true {
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: currentWeekStart) else { break }
            guard weekEnd >= rangeStart else { break }
            let lowerBound = max(currentWeekStart, rangeStart)
            let upperBound = min(weekEnd, startDay)
            let bucketWeekEnd = upperBound
            guard upperBound >= lowerBound else {
                guard let prev = calendar.date(byAdding: .day, value: -7, to: currentWeekStart) else { break }
                currentWeekStart = prev
                continue
            }

            var total = 0
            var complete = 0
            var cursor = lowerBound
            while cursor <= upperBound {
                if let activity = activitiesByDay[cursor] {
                    total += 1
                    if activity.isComplete { complete += 1 }
                } else {
                    // A day with no activity still counts toward the window's
                    // total days for an honest completion-rate.
                    total += 1
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }

            buckets.append(WeeklyBucket(
                weekStart: currentWeekStart,
                weekEnd: bucketWeekEnd,
                totalDays: total,
                completeDays: complete
            ))

            guard let prev = calendar.date(byAdding: .day, value: -7, to: currentWeekStart) else { break }
            currentWeekStart = prev
        }

        return buckets.reversed()
    }

    private func startOfWeek(containing date: Date, firstWeekday: Int) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let offset = ((weekday - firstWeekday) + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: date) ?? date
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

    private func completionRateInsights(snapshot: StreakSnapshot, today: Date, range: StreakRange) -> [StreakInsight] {
        var insights: [StreakInsight] = []

        let rate = completionRate(in: range, snapshot: snapshot, today: today)
        insights.append(StreakInsight(
            category: .completion,
            title: "\(range.title) Completion",
            message: "\(Int(rate * 100))% of the last \(range.dayCount) days were complete",
            value: rate,
            icon: "chart.bar.fill"
        ))

        return insights
    }

    func completionRate(in range: StreakRange, snapshot: StreakSnapshot, today: Date) -> Double {
        let activities = snapshot.activities
        var completeCount = 0
        for offset in 0..<range.dayCount {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = calendar.startOfDay(for: date)
            if let activity = activities.first(where: { calendar.isDate($0.date, inSameDayAs: key) }),
               activity.isComplete {
                completeCount += 1
            }
        }
        return Double(completeCount) / Double(range.dayCount)
    }

    // MARK: - Weak Days + Heatmap

    private func weakDayInsights(snapshot: StreakSnapshot, range: StreakRange, today: Date = Date()) -> [StreakInsight] {
        let weekdayStats = weekdayCompletionStats(snapshot: snapshot, range: range, today: today)
        guard !weekdayStats.isEmpty else { return [] }

        let heatmapData = buildHeatmapData(from: weekdayStats)

        let sorted = weekdayStats.sorted { $0.value < $1.value }
        guard let weakest = sorted.first, weakest.value < 0.5 else {
            return [StreakInsight(
                category: .pattern,
                title: "Weekly Heatmap",
                message: "Your completion rate by day of week",
                value: nil,
                icon: "calendar",
                heatmapData: heatmapData
            )]
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        let dayName = formatter.weekdaySymbols[weakest.key - 1]

        return [StreakInsight(
            category: .pattern,
            title: "Weekly Heatmap",
            message: "\(dayName) is your weakest day — \(Int(weakest.value * 100))% completion",
            value: nil,
            icon: "calendar",
            heatmapData: heatmapData
        )]
    }

    private func buildHeatmapData(from stats: [Int: Double]) -> WeekdayHeatmapData {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")

        let shortSymbols = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        guard let fullSymbols = formatter.weekdaySymbols else {
            return WeekdayHeatmapData(days: [])
        }

        let days: [WeekdayHeatmapData.Day] = (1...7).map { weekday in
            let rate = stats[weekday] ?? 0
            let idx = weekday - 1
            return WeekdayHeatmapData.Day(
                name: idx < fullSymbols.count ? fullSymbols[idx] : "Day",
                shortName: idx < shortSymbols.count ? shortSymbols[idx] : "?",
                completionRate: rate,
                totalDays: 0,
                completeDays: 0,
                breakRate: 0
            )
        }

        return WeekdayHeatmapData(days: days)
    }

    private func weekdayCompletionStats(snapshot: StreakSnapshot, range: StreakRange, today: Date = Date()) -> [Int: Double] {
        let cutoff = calendar.date(byAdding: .day, value: -(range.dayCount - 1), to: calendar.startOfDay(for: today)) ?? .distantPast
        var totals: [Int: Int] = [:]
        var completes: [Int: Int] = [:]

        for activity in snapshot.activities {
            guard activity.date >= cutoff else { continue }
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

    private func partialDayInsights(snapshot: StreakSnapshot, range: StreakRange, today: Date = Date()) -> [StreakInsight] {
        let cutoff = calendar.date(byAdding: .day, value: -(range.dayCount - 1), to: calendar.startOfDay(for: today)) ?? .distantPast
        var meditationOnly = 0
        var noteOnly = 0

        for activity in snapshot.activities where activity.date >= cutoff {
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

    private func timeOfDayInsights(snapshot: StreakSnapshot, range: StreakRange, today: Date = Date()) -> [StreakInsight] {
        let cutoff = calendar.date(byAdding: .day, value: -(range.dayCount - 1), to: calendar.startOfDay(for: today)) ?? .distantPast
        var meditationHours: [Int] = []
        var noteHours: [Int] = []

        for activity in snapshot.activities where activity.date >= cutoff {
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

    private func trendInsights(snapshot: StreakSnapshot, today: Date, range: StreakRange) -> [StreakInsight] {
        guard !snapshot.activities.isEmpty else { return [] }

        // The window is split into halves; first-half vs second-half completion
        // counts become the trend arrow regardless of the selected range.
        let half = max(1, range.dayCount / 2)
        let secondHalf = completeDaysCount(in: half, snapshot: snapshot, today: today)
        let firstHalfStart = calendar.date(byAdding: .day, value: -half, to: today) ?? today
        let firstHalf = completeDaysCount(in: half, snapshot: snapshot, today: firstHalfStart)

        let diff = secondHalf - firstHalf
        let trend: String
        let icon: String
        if diff > 0 {
            trend = "↑ +\(diff) from previous \(half) days"
            icon = "arrow.up.right"
        } else if diff < 0 {
            trend = "↓ \(diff) from previous \(half) days"
            icon = "arrow.down.right"
        } else {
            trend = "→ Same as previous \(half) days"
            icon = "arrow.right"
        }

        return [StreakInsight(
            category: .trend,
            title: "\(range.shortLabel) Trend",
            message: "\(secondHalf)/\(half) recent days — \(trend)",
            value: Double(secondHalf) / Double(half),
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

    private func balanceInsights(snapshot: StreakSnapshot, range: StreakRange, today: Date = Date()) -> [StreakInsight] {
        let cutoff = calendar.date(byAdding: .day, value: -(range.dayCount - 1), to: calendar.startOfDay(for: today)) ?? .distantPast
        let windowed = snapshot.activities.filter { $0.date >= cutoff }
        let totalDays = windowed.count
        guard totalDays > 0 else { return [] }

        let meditationDays = windowed.filter(\.hasMeditation).count
        let noteDays = windowed.filter(\.hasNote).count

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
            title: "\(range.shortLabel) Balance",
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
        case "calendar.badge.exclamationmark", "calendar":
            guard let heatmap = insight.heatmapData,
                  let weakest = heatmap.days.min(by: { $0.completionRate < $1.completionRate }),
                  weakest.completionRate < 0.5 else { return nil }
            return UserRecommendation(
                priority: .medium,
                title: "Plan ahead for \(weakest.name)s",
                message: "\(weakest.name) is your weakest day — set a reminder",
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

    // MARK: - Lifetime: streak runs

    /// One complete-day run. `breakWeekday` is the weekday (1...7) of the
    /// first calendar day *after* the run where `isComplete` was false
    /// (or no activity existed). `nil` for the trailing run that may
    /// still be alive — the user has not yet broken or completed it.
    private struct StreakRun {
        let length: Int
        let breakWeekday: Int?
    }

    /// Extracts runs of consecutive complete days from the snapshot in
    /// chronological order. Days are deduplicated and gap-tolerant: a
    /// calendar day without an activity is treated as "not complete" and
    /// ends the current run, but the run is annotated with the weekday
    /// of that day (the day on which the streak broke).
    ///
    /// Runs are derived purely from `snapshot.activities` — no call into
    /// `StreakEngine` — so the two engines stay decoupled.
    private func extractStreakRuns(from snapshot: StreakSnapshot) -> [StreakRun] {
        let activityByDay = Dictionary(
            snapshot.activities.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let sortedDays = activityByDay.keys.sorted()
        guard !sortedDays.isEmpty else { return [] }

        var runs: [StreakRun] = []
        var currentLength = 0
        var previousDay: Date?

        for day in sortedDays {
            let isComplete = activityByDay[day]?.isComplete == true

            // If a calendar day is missing between previousDay and day,
            // the streak broke before `day`. Close out the current run
            // and label the first missing day as the break.
            if let prev = previousDay,
               let expectedNext = calendar.date(byAdding: .day, value: 1, to: prev),
               !calendar.isDate(day, inSameDayAs: expectedNext) {
                if currentLength > 0 {
                    runs.append(StreakRun(
                        length: currentLength,
                        breakWeekday: calendar.component(.weekday, from: expectedNext)
                    ))
                }
                currentLength = 0
            }

            if isComplete {
                currentLength += 1
            } else {
                if currentLength > 0 {
                    runs.append(StreakRun(
                        length: currentLength,
                        breakWeekday: calendar.component(.weekday, from: day)
                    ))
                }
                currentLength = 0
            }

            previousDay = day
        }

        // Trailing run: kept as-is with no break weekday. The engine
        // cannot know yet whether it has been broken.
        if currentLength > 0 {
            runs.append(StreakRun(length: currentLength, breakWeekday: nil))
        }

        return runs
    }

    // MARK: - Lifetime: distribution

    /// Buckets every run into the fixed six buckets
    /// `[1 / 2 / 3 / 4-6 / 7-13 / 14+]` and computes the median length.
    /// Returns an empty distribution (zero streaks) for an empty
    /// snapshot.
    func streakLengthDistribution(from snapshot: StreakSnapshot) -> StreakLengthDistribution {
        let runs = extractStreakRuns(from: snapshot)
        let lengths = runs.map(\.length)

        var counts = Array(repeating: 0, count: StreakLengthDistribution.canonicalBuckets.count)
        for length in lengths {
            for (index, range) in StreakLengthDistribution.canonicalBuckets.enumerated()
            where range.contains(length) {
                counts[index] += 1
                break
            }
        }

        let buckets = zip(
            StreakLengthDistribution.canonicalBuckets,
            StreakLengthDistribution.canonicalLabels
        ).enumerated().map { index, pair in
            StreakLengthDistribution.Bucket(
                range: pair.0,
                label: pair.1,
                count: counts[index]
            )
        }

        return StreakLengthDistribution(
            buckets: buckets,
            totalStreaks: lengths.count,
            medianLength: median(of: lengths)
        )
    }

    // MARK: - Lifetime: resilience

    /// Computes recovery gap (in calendar days) between consecutive runs
    /// and the empirical survival curve: `survivalByDay[n]` is the
    /// fraction of runs of length >= n that survived to length n+1.
    /// `avgRecoveryDays` is the mean of recovery gaps; 0 when there are
    /// no recoveries.
    func resilience(from snapshot: StreakSnapshot) -> StreakResilience {
        let runs = extractStreakRuns(from: snapshot)
        guard !runs.isEmpty else {
            return StreakResilience(
                avgRecoveryDays: 0,
                longestRecoveryDays: 0,
                totalRecoveries: 0,
                survivalByDay: [:]
            )
        }

        let activityByDay = Dictionary(
            snapshot.activities.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let sortedDays = activityByDay.keys.sorted()

        // Recovery gaps: walk the sorted days, and when a gap appears
        // (next day is not the previous+1) and both ends touch a
        // complete run, count the gap length.
        var recoveryGaps: [Int] = []
        var previousRunEnd: Date?
        for day in sortedDays {
            guard let prev = previousRunEnd else {
                if activityByDay[day]?.isComplete == true {
                    previousRunEnd = day
                }
                continue
            }
            guard let expectedNext = calendar.date(byAdding: .day, value: 1, to: prev) else {
                break
            }
            if calendar.isDate(day, inSameDayAs: expectedNext) {
                if activityByDay[day]?.isComplete == true {
                    previousRunEnd = day
                } else {
                    // The previous run ended one day ago; this day is
                    // the first non-complete day. Reset.
                    previousRunEnd = nil
                }
                continue
            }
            // Day is later than prev+1: there is a gap.
            if activityByDay[day]?.isComplete == true {
                let gap = calendar.dateComponents([.day], from: prev, to: day).day ?? 0
                recoveryGaps.append(gap)
                previousRunEnd = day
            } else {
                previousRunEnd = nil
            }
        }

        // Survival: P(run of length >= n+1 | run of length >= n).
        // We approximate by, for each n, counting runs of length >= n
        // that also have length >= n+1.
        let lengths = runs.map(\.length)
        var survival: [Int: Double] = [:]
        let maxLength = lengths.max() ?? 0
        for n in 1..<maxLength {
            let eligible = lengths.filter { $0 >= n }.count
            guard eligible > 0 else { continue }
            let survived = lengths.filter { $0 >= n + 1 }.count
            survival[n] = Double(survived) / Double(eligible)
        }

        let avg = recoveryGaps.isEmpty
            ? 0.0
            : Double(recoveryGaps.reduce(0, +)) / Double(recoveryGaps.count)

        return StreakResilience(
            avgRecoveryDays: avg,
            longestRecoveryDays: recoveryGaps.max() ?? 0,
            totalRecoveries: recoveryGaps.count,
            survivalByDay: survival
        )
    }

    // MARK: - Lifetime: weekday break pattern

    /// Returns, for each weekday (1...7), the fraction of streak breaks
    /// whose first missing day fell on that weekday. Days with no
    /// recorded breaks get 0.
    func weekdayBreakPattern(from snapshot: StreakSnapshot) -> [Int: Double] {
        let runs = extractStreakRuns(from: snapshot)
        let breakWeekdays = runs.compactMap(\.breakWeekday)
        guard !breakWeekdays.isEmpty else { return [:] }

        var counts: [Int: Int] = [:]
        for weekday in breakWeekdays {
            counts[weekday, default: 0] += 1
        }
        let total = breakWeekdays.count
        return counts.mapValues { Double($0) / Double(total) }
    }

    /// Same shape as the existing range-windowed heatmap, but enriched
    /// with the lifetime `breakRate` for each weekday. Use this when
    /// rendering the lifetime section; the existing `weakDayInsights`
    /// path remains unchanged for the range-aware UI.
    func weekdayBreakHeatmapData(from snapshot: StreakSnapshot) -> WeekdayHeatmapData {
        let completionStats = lifetimeWeekdayCompletionStats(snapshot: snapshot)
        let breakPattern = weekdayBreakPattern(from: snapshot)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        let shortSymbols = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        guard let fullSymbols = formatter.weekdaySymbols else {
            return WeekdayHeatmapData(days: [])
        }

        let days: [WeekdayHeatmapData.Day] = (1...7).map { weekday in
            let stats = completionStats[weekday]
            let idx = weekday - 1
            return WeekdayHeatmapData.Day(
                name: idx < fullSymbols.count ? fullSymbols[idx] : "Day",
                shortName: idx < shortSymbols.count ? shortSymbols[idx] : "?",
                completionRate: stats?.completionRate ?? 0,
                totalDays: stats?.totalDays ?? 0,
                completeDays: stats?.completeDays ?? 0,
                breakRate: breakPattern[weekday] ?? 0
            )
        }

        return WeekdayHeatmapData(days: days)
    }

    private func lifetimeWeekdayCompletionStats(snapshot: StreakSnapshot) -> [Int: (completionRate: Double, totalDays: Int, completeDays: Int)] {
        var totals: [Int: Int] = [:]
        var completes: [Int: Int] = [:]
        for activity in snapshot.activities {
            let weekday = calendar.component(.weekday, from: activity.date)
            totals[weekday, default: 0] += 1
            if activity.isComplete {
                completes[weekday, default: 0] += 1
            }
        }
        var result: [Int: (completionRate: Double, totalDays: Int, completeDays: Int)] = [:]
        for (weekday, total) in totals {
            let complete = completes[weekday] ?? 0
            result[weekday] = (Double(complete) / Double(total), total, complete)
        }
        return result
    }

    private func median(of values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
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
