//
//  UserDefaultsStreakStore.swift
//  MeditateAndNote
//
//  UserDefaults implementation of StreakActivityStore.
//  Mirrors UserDefaultsReminderSettingsStore.
//

import Foundation
import OSLog

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
        let meditationTime: Date?
        let noteTime: Date?

        init(from activity: DailyActivity) {
            self.date = activity.date
            self.hasMeditation = activity.hasMeditation
            self.hasNote = activity.hasNote
            self.meditationTime = activity.meditationTime
            self.noteTime = activity.noteTime
        }

        func toDailyActivity() -> DailyActivity {
            DailyActivity(
                date: date,
                hasMeditation: hasMeditation,
                hasNote: hasNote,
                meditationTime: meditationTime,
                noteTime: noteTime
            )
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

    func save(_ snapshot: StreakSnapshot) async {
        persist(snapshot)
    }

    /// Synchronous persistence used by both `save` and legacy migration; the
    /// UserDefaults write is non-blocking so no actor hop is introduced inside
    /// `load()` (which must stay synchronous for `StreakTracker.init`).
    private func persist(_ snapshot: StreakSnapshot) {
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
            persist(snapshot)
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
