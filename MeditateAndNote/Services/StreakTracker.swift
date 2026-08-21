//
//  StreakTracker.swift
//  MeditateAndNote
//

import Foundation
import OSLog

// MARK: - StreakActivityStore (persistence boundary / ACL)

struct StreakSnapshot {
    let activities: [DailyActivity]
    let currentStreak: Int
    let longestStreak: Int
    let lastCountedDay: Date?
}

protocol StreakActivityStore {
    func load() -> StreakSnapshot?
    func save(_ snapshot: StreakSnapshot)
}

// MARK: - UserDefaults Implementation

final class UserDefaultsStreakStore: StreakActivityStore {
    private static let activitiesKey = "streakDailyActivities"
    private static let currentKey = "streakCurrent"
    private static let longestKey = "streakLongest"
    private static let lastCountedKey = "streakLastCountedDay"

    private let logger = Logger(subsystem: Config.bundleID, category: "StreakPersistence")
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func load() -> StreakSnapshot? {
        guard let data = defaults.data(forKey: Self.activitiesKey) else { return nil }
        do {
            let decoded = try JSONDecoder().decode([CodableDailyActivity].self, from: data)
            return StreakSnapshot(
                activities: decoded.map { $0.toDailyActivity() },
                currentStreak: defaults.integer(forKey: Self.currentKey),
                longestStreak: defaults.integer(forKey: Self.longestKey),
                lastCountedDay: defaults.object(forKey: Self.lastCountedKey) as? Date
            )
        } catch {
            logger.error("Failed to load streak activities — \(error.localizedDescription)")
            return nil
        }
    }

    func save(_ snapshot: StreakSnapshot) {
        do {
            let codable = snapshot.activities.map { CodableDailyActivity(from: $0) }
            let data = try JSONEncoder().encode(codable)
            defaults.set(data, forKey: Self.activitiesKey)
        } catch {
            logger.error("Failed to persist streak activities — \(error.localizedDescription)")
        }
        defaults.set(snapshot.currentStreak, forKey: Self.currentKey)
        defaults.set(snapshot.longestStreak, forKey: Self.longestKey)
        if let day = snapshot.lastCountedDay {
            defaults.set(day, forKey: Self.lastCountedKey)
        } else {
            defaults.removeObject(forKey: Self.lastCountedKey)
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

// MARK: - StreakTracker (pure domain logic)

@Observable
final class StreakTracker: @unchecked Sendable {

    private(set) var currentStreak: Int = 0
    private(set) var longestStreak: Int = 0
    private(set) var dailyActivities: [Date: DailyActivity] = [:]

    private var lastCountedDay: Date?

    private let calendar: Calendar
    private let store: StreakActivityStore
    private let eventBus: DomainEventPublisher

    convenience init(calendar: Calendar = .current,
                     defaults: UserDefaults = .standard,
                     eventBus: DomainEventPublisher = DomainEventBus.shared) {
        self.init(calendar: calendar, eventBus: eventBus, store: UserDefaultsStreakStore(defaults: defaults))
    }

    init(calendar: Calendar, eventBus: DomainEventPublisher, store: StreakActivityStore) {
        self.calendar = calendar
        self.eventBus = eventBus
        self.store = store
        if let snapshot = store.load() {
            dailyActivities = Dictionary(uniqueKeysWithValues: snapshot.activities.map { ($0.date, $0) })
            currentStreak = snapshot.currentStreak
            longestStreak = snapshot.longestStreak
            lastCountedDay = snapshot.lastCountedDay.map { startOfDay($0) }
        }
        checkStreakBreak()
    }

    // MARK: - Public API

    func markNoteCreated(date: Date = .now) {
        let key = startOfDay(date)
        ensureActivityExists(for: key)
        dailyActivities[key]?.hasNote = true
        updateStreak(today: key)
        persist()
    }

    func markMeditationCompleted(date: Date = .now) {
        let key = startOfDay(date)
        ensureActivityExists(for: key)
        dailyActivities[key]?.hasMeditation = true
        updateStreak(today: key)
        persist()
    }

    func checkStreakBreak() {
        let today = startOfDay(.now)
        let yesterday = startOfDay(today.addingTimeInterval(-86_400))
        let todayActivity = dailyActivities[today]
        let yesterdayComplete = dailyActivities[yesterday]?.isComplete ?? false

        if !yesterdayComplete && !(todayActivity?.isComplete ?? false) {
            currentStreak = 0
            lastCountedDay = nil
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
        lastCountedDay = sortedDays.last(where: { activities[$0]?.isComplete ?? false })
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

    private func updateStreak(today: Date) {
        guard dailyActivities[today]?.isComplete ?? false else { return }
        guard lastCountedDay != today else { return }

        let yesterday = startOfDay(today.addingTimeInterval(-86_400))
        let yesterdayComplete = dailyActivities[yesterday]?.isComplete ?? false

        currentStreak = (yesterdayComplete && currentStreak > 0) ? currentStreak + 1 : 1
        if currentStreak > longestStreak { longestStreak = currentStreak }
        lastCountedDay = today
        eventBus.publish(StreakChanged(currentStreak: currentStreak, longestStreak: longestStreak))
    }

    private func ensureActivityExists(for date: Date) {
        guard dailyActivities[date] == nil else { return }
        dailyActivities[date] = DailyActivity(date: date, hasMeditation: false, hasNote: false)
    }

    private func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func persist() {
        store.save(StreakSnapshot(
            activities: Array(dailyActivities.values),
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastCountedDay: lastCountedDay
        ))
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
