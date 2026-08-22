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
    /// Loads the last saved snapshot, or nil when nothing valid is stored.
    /// Implementations must never return a partially populated snapshot.
    func load() -> StreakSnapshot?
    /// Persists the snapshot atomically: either every field lands in storage,
    /// or none does.
    func save(_ snapshot: StreakSnapshot)
}

// MARK: - UserDefaults Implementation

final class UserDefaultsStreakStore: StreakActivityStore {
    private static let snapshotKey = "streakSnapshot"
    private static let legacyActivitiesKey = "streakDailyActivities"
    private static let legacyCurrentKey = "streakCurrent"
    private static let legacyLongestKey = "streakLongest"
    private static let legacyLastCountedKey = "streakLastCountedDay"

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

    private struct CodableSnapshot: Codable {
        let activities: [CodableDailyActivity]
        let currentStreak: Int
        let longestStreak: Int
        let lastCountedDay: Date?

        init(from snapshot: StreakSnapshot) {
            self.activities = snapshot.activities.map(CodableDailyActivity.init(from:))
            self.currentStreak = snapshot.currentStreak
            self.longestStreak = snapshot.longestStreak
            self.lastCountedDay = snapshot.lastCountedDay
        }

        func toSnapshot() -> StreakSnapshot {
            StreakSnapshot(
                activities: activities.map { $0.toDailyActivity() },
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                lastCountedDay: lastCountedDay
            )
        }
    }

    private let logger = Logger(subsystem: Config.bundleID, category: "StreakPersistence")
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func load() -> StreakSnapshot? {
        if let data = defaults.data(forKey: Self.snapshotKey) {
            do {
                return try JSONDecoder().decode(CodableSnapshot.self, from: data).toSnapshot()
            } catch {
                logger.error("Failed to decode streak snapshot — \(error.localizedDescription)")
                return nil
            }
        }
        return migrateLegacyState()
    }

    func save(_ snapshot: StreakSnapshot) {
        do {
            let data = try JSONEncoder().encode(CodableSnapshot(from: snapshot))
            defaults.set(data, forKey: Self.snapshotKey)
        } catch {
            logger.error("Failed to persist streak snapshot — \(error.localizedDescription)")
        }
    }

    private func migrateLegacyState() -> StreakSnapshot? {
        guard let data = defaults.data(forKey: Self.legacyActivitiesKey) else { return nil }
        do {
            let activities = try JSONDecoder().decode([CodableDailyActivity].self, from: data)
                .map { $0.toDailyActivity() }
            let snapshot = StreakSnapshot(
                activities: activities,
                currentStreak: defaults.integer(forKey: Self.legacyCurrentKey),
                longestStreak: defaults.integer(forKey: Self.legacyLongestKey),
                lastCountedDay: defaults.object(forKey: Self.legacyLastCountedKey) as? Date
            )
            save(snapshot)
            defaults.removeObject(forKey: Self.legacyActivitiesKey)
            defaults.removeObject(forKey: Self.legacyCurrentKey)
            defaults.removeObject(forKey: Self.legacyLongestKey)
            defaults.removeObject(forKey: Self.legacyLastCountedKey)
            return snapshot
        } catch {
            logger.error("Failed to migrate legacy streak state — \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - ActivityHistory

struct ActivityHistory {
    let noteDates: [Date]
    let meditationDates: [Date]

    init(noteDates: [Date] = [], meditationDates: [Date] = []) {
        self.noteDates = noteDates
        self.meditationDates = meditationDates
    }
}

// MARK: - StreakEngine (pure domain logic)

struct StreakEngine {
    private let calendar: Calendar
    private(set) var dailyActivities: [Date: DailyActivity] = [:]
    private(set) var currentStreak: Int = 0
    private(set) var longestStreak: Int = 0
    private(set) var lastCountedDay: Date?

    init(calendar: Calendar, snapshot: StreakSnapshot? = nil) {
        self.calendar = calendar
        if let snapshot {
            dailyActivities = Dictionary(uniqueKeysWithValues: snapshot.activities.map { ($0.date, $0) })
            currentStreak = snapshot.currentStreak
            longestStreak = snapshot.longestStreak
            lastCountedDay = snapshot.lastCountedDay.map { startOfDay($0) }
        }
    }

    var snapshot: StreakSnapshot {
        StreakSnapshot(
            activities: Array(dailyActivities.values),
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastCountedDay: lastCountedDay
        )
    }

    mutating func markNoteCreated(on date: Date) -> StreakChanged? {
        let key = startOfDay(date)
        ensureActivityExists(for: key)
        dailyActivities[key]?.hasNote = true
        return updateStreak(today: key)
    }

    mutating func markMeditationCompleted(on date: Date) -> StreakChanged? {
        let key = startOfDay(date)
        ensureActivityExists(for: key)
        dailyActivities[key]?.hasMeditation = true
        return updateStreak(today: key)
    }

    mutating func checkStreakBreak(now: Date = .now) {
        let today = startOfDay(now)
        let yesterday = startOfDay(now.addingTimeInterval(-86_400))
        let yesterdayComplete = dailyActivities[yesterday]?.isComplete ?? false
        let todayComplete = dailyActivities[today]?.isComplete ?? false

        if !yesterdayComplete && !todayComplete {
            currentStreak = 0
            lastCountedDay = nil
        }
    }

    mutating func recalculate(_ history: ActivityHistory) {
        var activities: [Date: DailyActivity] = [:]

        for raw in history.noteDates {
            let key = startOfDay(raw)
            if activities[key] == nil {
                activities[key] = DailyActivity(date: key, hasMeditation: false, hasNote: false)
            }
            activities[key]?.hasNote = true
        }

        for raw in history.meditationDates {
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
    }

    func activity(for date: Date) -> DailyActivity {
        let key = startOfDay(date)
        return dailyActivities[key] ?? DailyActivity(date: key, hasMeditation: false, hasNote: false)
    }

    func isTodayComplete(now: Date = .now) -> Bool {
        activity(for: now).isComplete
    }

    private mutating func updateStreak(today: Date) -> StreakChanged? {
        guard dailyActivities[today]?.isComplete ?? false else { return nil }
        guard lastCountedDay != today else { return nil }

        let yesterday = startOfDay(today.addingTimeInterval(-86_400))
        let yesterdayComplete = dailyActivities[yesterday]?.isComplete ?? false

        currentStreak = (yesterdayComplete && currentStreak > 0) ? currentStreak + 1 : 1
        if currentStreak > longestStreak { longestStreak = currentStreak }
        lastCountedDay = today
        return StreakChanged(currentStreak: currentStreak, longestStreak: longestStreak)
    }

    private mutating func ensureActivityExists(for date: Date) {
        guard dailyActivities[date] == nil else { return }
        dailyActivities[date] = DailyActivity(date: date, hasMeditation: false, hasNote: false)
    }

    private func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}

// MARK: - StreakTracker (observable adapter over the domain engine)

@Observable
final class StreakTracker {

    private(set) var currentStreak: Int = 0
    private(set) var longestStreak: Int = 0
    private(set) var dailyActivities: [Date: DailyActivity] = [:]

    private var engine: StreakEngine
    private let store: StreakActivityStore
    private let eventBus: DomainEventPublisher

    convenience init(calendar: Calendar = .current,
                     defaults: UserDefaults = .standard,
                     eventBus: DomainEventPublisher = DomainEventBus.shared) {
        self.init(calendar: calendar, eventBus: eventBus, store: UserDefaultsStreakStore(defaults: defaults))
    }

    init(calendar: Calendar, eventBus: DomainEventPublisher, store: StreakActivityStore) {
        self.store = store
        self.eventBus = eventBus
        self.engine = StreakEngine(calendar: calendar, snapshot: store.load())
        engine.checkStreakBreak()
        mirrorEngine()
    }

    // MARK: - Public API

    func markNoteCreated(date: Date = .now) {
        apply { $0.markNoteCreated(on: date) }
    }

    func markMeditationCompleted(date: Date = .now) {
        apply { $0.markMeditationCompleted(on: date) }
    }

    func checkStreakBreak() {
        engine.checkStreakBreak()
        mirrorEngine()
    }

    func fullRecalculation(_ history: ActivityHistory) {
        apply {
            $0.recalculate(history)
            return nil
        }
    }

    func activity(for date: Date) -> DailyActivity {
        engine.activity(for: date)
    }

    var isTodayComplete: Bool {
        engine.isTodayComplete()
    }

    // MARK: - Private

    private func apply(_ mutation: (inout StreakEngine) -> StreakChanged?) {
        var next = engine
        let change = mutation(&next)
        engine = next
        mirrorEngine()
        persist()

        if let change {
            eventBus.publish(change)
        }
    }

    private func mirrorEngine() {
        currentStreak = engine.currentStreak
        longestStreak = engine.longestStreak
        dailyActivities = engine.dailyActivities
    }

    private func persist() {
        store.save(engine.snapshot)
    }
}

// MARK: - Domain Event Subscription

extension StreakTracker: DomainEventVisitor {
    func visit(_ event: NoteCreated) {
        markNoteCreated(date: event.date)
    }

    func visit(_ event: NoteUpdated) {}

    func visit(_ event: NoteDeleted) {}

    func visit(_ event: MeditationCompleted) {
        markMeditationCompleted(date: event.session.completedAt)
    }

    func visit(_ event: StreakChanged) {}
}
