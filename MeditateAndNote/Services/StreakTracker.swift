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
    private var lastKnownGood: StreakSnapshot?

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func load() -> StreakSnapshot? {
        if let data = defaults.data(forKey: Self.snapshotKey) {
            do {
                let snapshot = try JSONDecoder().decode(CodableSnapshot.self, from: data).toSnapshot()
                lastKnownGood = snapshot
                return snapshot
            } catch {
                logger.error("Failed to decode streak snapshot, keeping last known good state — \(error.localizedDescription)")
                return lastKnownGood
            }
        }
        let migrated = migrateLegacyState()
        lastKnownGood = migrated ?? lastKnownGood
        return migrated ?? lastKnownGood
    }

    func save(_ snapshot: StreakSnapshot) {
        do {
            let data = try JSONEncoder().encode(CodableSnapshot(from: snapshot))
            defaults.set(data, forKey: Self.snapshotKey)
            lastKnownGood = snapshot
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
            dailyActivities = Dictionary(
                snapshot.activities.map { ($0.date, $0) },
                uniquingKeysWith: { current, next in
                    DailyActivity(
                        date: current.date,
                        hasMeditation: current.hasMeditation || next.hasMeditation,
                        hasNote: current.hasNote || next.hasNote
                    )
                }
            )
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

    mutating func markNoteCreated(on date: Date) {
        let key = startOfDay(date)
        ensureActivityExists(for: key)
        dailyActivities[key]?.hasNote = true
        updateStreak(today: key)
    }

    mutating func markMeditationCompleted(on date: Date) {
        let key = startOfDay(date)
        ensureActivityExists(for: key)
        dailyActivities[key]?.hasMeditation = true
        updateStreak(today: key)
    }

    mutating func checkStreakBreak(now: Date = .now) {
        let today = startOfDay(now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        let yesterdayComplete = yesterday.flatMap { dailyActivities[$0] }?.isComplete ?? false
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
                    let prevDay = calendar.date(byAdding: .day, value: -1, to: day)
                    if prevDay.flatMap({ activities[$0] })?.isComplete ?? false {
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

    private mutating func updateStreak(today: Date) {
        guard dailyActivities[today]?.isComplete ?? false else { return }
        guard lastCountedDay != today else { return }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        let yesterdayComplete = yesterday.flatMap { dailyActivities[$0] }?.isComplete ?? false

        currentStreak = (yesterdayComplete && currentStreak > 0) ? currentStreak + 1 : 1
        if currentStreak > longestStreak { longestStreak = currentStreak }
        lastCountedDay = today
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

    var totalCompleteDays: Int {
        engine.dailyActivities.values.filter(\.isComplete).count
    }

    private var dailyActivities: [Date: DailyActivity] = [:]

    private var engine: StreakEngine
    private let store: StreakActivityStore

    convenience init(calendar: Calendar = .current,
                     defaults: UserDefaults = .standard) {
        self.init(calendar: calendar, store: UserDefaultsStreakStore(defaults: defaults))
    }

    init(calendar: Calendar, store: StreakActivityStore) {
        self.store = store
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
        }
    }

    func activity(for date: Date) -> DailyActivity {
        engine.activity(for: date)
    }

    var isTodayComplete: Bool {
        engine.isTodayComplete()
    }

    // MARK: - Private

    private func apply(_ mutation: (inout StreakEngine) -> Void) {
        var next = engine
        mutation(&next)
        engine = next
        mirrorEngine()
        persist()
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

extension StreakTracker {
    /// Exhaustive switch: adding a new DomainEvent case breaks compilation here,
    /// forcing an explicit streak decision for it.
    func handle(_ event: DomainEvent) {
        switch event {
        case let .noteCreated(note):
            markNoteCreated(date: note.date)

        case .noteUpdated, .noteDeleted:
            break

        case let .meditationCompleted(session):
            markMeditationCompleted(date: session.completedAt)
        }
    }
}
