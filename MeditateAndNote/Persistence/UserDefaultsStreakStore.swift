//
//  UserDefaultsStreakStore.swift
//  MeditateAndNote
//
//  UserDefaults implementation of StreakActivityStore.
//  Mirrors UserDefaultsReminderSettingsStore.
//

import Foundation
import MeditateAndNoteCore

final class UserDefaultsStreakStore: StreakActivityStore, @unchecked Sendable {
    private static let snapshotKey = "streakSnapshot"
    private static let legacyActivitiesKey = "streakDailyActivities"
    private static let legacyCurrentKey = "streakCurrent"
    private static let legacyLongestKey = "streakLongest"
    private static let legacyLastCountedKey = "streakLastCountedDay"

    private let logger = Logger(subsystem: Config.bundleID, category: "StreakPersistence")
    private let defaults: UserDefaults
    private var lastKnownGood: StreakSnapshot?

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func load() -> StreakSnapshot? {
        if let data = defaults.data(forKey: Self.snapshotKey) {
            do {
                let snapshot = try JSONDecoder().decode(StreakSnapshot.self, from: data)
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
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: Self.snapshotKey)
            lastKnownGood = snapshot
        } catch {
            logger.error("Failed to persist streak snapshot — \(error.localizedDescription)")
        }
    }

    private func migrateLegacyState() -> StreakSnapshot? {
        guard let data = defaults.data(forKey: Self.legacyActivitiesKey) else { return nil }
        do {
            let activities = try JSONDecoder().decode([DailyActivity].self, from: data)
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
