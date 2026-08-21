//
//  StreakTracker.swift
//  MeditateAndNote
//

import Foundation

@Observable
final class StreakTracker: @unchecked Sendable {

    private(set) var currentStreak: Int = 0
    private(set) var longestStreak: Int = 0
    private(set) var dailyActivities: [Date: DailyActivity] = [:]

    private let calendar: Calendar
    private let defaults: UserDefaults

    init(calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        self.calendar = calendar
        self.defaults = defaults
        load()
        checkStreakBreak()
    }

    // MARK: - Public API

    func markNoteCreated(date: Date = .now) {
        let key = startOfDay(date)
        ensureActivityExists(for: key)
        dailyActivities[key]?.hasNote = true
        recalculateStreak(today: key)
        if currentStreak > longestStreak { longestStreak = currentStreak }
        persist()
    }

    func markMeditationCompleted(date: Date = .now) {
        let key = startOfDay(date)
        ensureActivityExists(for: key)
        dailyActivities[key]?.hasMeditation = true
        recalculateStreak(today: key)
        if currentStreak > longestStreak { longestStreak = currentStreak }
        persist()
    }

    func checkStreakBreak() {
        let today = startOfDay(.now)
        let yesterday = startOfDay(today.addingTimeInterval(-86_400))
        let todayActivity = dailyActivities[today]
        let yesterdayComplete = dailyActivities[yesterday]?.isComplete ?? false

        if !yesterdayComplete && !(todayActivity?.isComplete ?? false) {
            currentStreak = 0
        }
    }

    func fullRecalculation(noteDates: [Date], meditationDates: [Date]) {
        var activities: [Date: DailyActivity] = [:]

        for raw in noteDates {
            let key = startOfDay(raw)
            if activities[key] == nil {
                activities[key] = DailyActivity(date: key, hasMeditation: false, hasNote: false)
            }
            activities[key]?.hasNote = true
        }

        for raw in meditationDates {
            let key = startOfDay(raw)
            if activities[key] == nil {
                activities[key] = DailyActivity(date: key, hasMeditation: false, hasNote: false)
            }
            activities[key]?.hasMeditation = true
        }

        dailyActivities = activities
        longestStreak = 0
        currentStreak = 0

        let sortedDays = activities.keys.sorted()
        var running = 0

        for day in sortedDays {
            let complete = activities[day]?.isComplete ?? false
            if complete {
                if running == 0 {
                    running = 1
                } else {
                    let prevDay = day.addingTimeInterval(-86_400)
                    if activities[prevDay]?.isComplete ?? false {
                        running += 1
                    } else {
                        running = 1
                    }
                }
                longestStreak = max(longestStreak, running)
            } else {
                running = 0
            }
        }

        currentStreak = running
        if currentStreak > longestStreak { longestStreak = currentStreak }
        persist()
    }

    func activity(for date: Date) -> DailyActivity {
        let key = startOfDay(date)
        return dailyActivities[key] ?? DailyActivity(date: key, hasMeditation: false, hasNote: false)
    }

    var isTodayComplete: Bool {
        activity(for: Date()).isComplete
    }

    // MARK: - Private

    private func recalculateStreak(today: Date) {
        let yesterday = today.addingTimeInterval(-86_400)
        let todayComplete = dailyActivities[today]?.isComplete ?? false
        let yesterdayComplete = dailyActivities[yesterday]?.isComplete ?? false

        guard todayComplete else { return }

        if yesterdayComplete {
            currentStreak += 1
        } else {
            currentStreak = 1
        }
    }

    private func ensureActivityExists(for date: Date) {
        guard dailyActivities[date] == nil else { return }
        dailyActivities[date] = DailyActivity(date: date, hasMeditation: false, hasNote: false)
    }

    private func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func persist() {
        do {
            let codable = dailyActivities.values.map { CodableDailyActivity(from: $0) }
            let data = try JSONEncoder().encode(codable)
            defaults.set(data, forKey: "streakDailyActivities")
        } catch {
            print("StreakTracker: failed to persist activities — \(error)")
        }
        defaults.set(currentStreak, forKey: "streakCurrent")
        defaults.set(longestStreak, forKey: "streakLongest")
    }

    private func load() {
        guard let data = defaults.data(forKey: "streakDailyActivities") else { return }
        do {
            let decoded = try JSONDecoder().decode([CodableDailyActivity].self, from: data)
            dailyActivities = Dictionary(uniqueKeysWithValues: decoded.map { ($0.date, $0.toDailyActivity()) })
            currentStreak = defaults.integer(forKey: "streakCurrent")
            longestStreak = defaults.integer(forKey: "streakLongest")
        } catch {
            print("StreakTracker: failed to load activities — \(error)")
        }
    }
}

// MARK: - Codable wrapper (Date keys require manual Codable conformance)

private struct CodableDailyActivity: Codable {
    let date: Date
    let hasMeditation: Bool
    let hasNote: Bool

    init(from activity: DailyActivity) {
        self.date = activity.date
        self.hasMeditation = activity.hasMeditation
        self.hasNote = activity.hasNote
    }

    func toDailyActivity() -> DailyActivity {
        DailyActivity(date: date, hasMeditation: hasMeditation, hasNote: hasNote)
    }
}

// MARK: - Domain Event Subscription

extension StreakTracker: DomainEventSubscriber {
    func handle(_ event: DomainEvent) {
        switch event {
        case let event as NoteCreated:
            markNoteCreated(date: event.note.date)
        case let event as MeditationCompleted:
            markMeditationCompleted(date: event.session.completedAt)
        default:
            break
        }
    }
}
