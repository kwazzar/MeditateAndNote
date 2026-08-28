//
//  CoreDataStreakStore.swift
//  MeditateAndNote
//
//  Core Data implementation of StreakActivityStore.
//

import CoreData
import Foundation
import OSLog

final class CoreDataStreakStore: StreakActivityStore {

    private let logger = Logger(subsystem: Config.bundleID, category: "CoreDataStreaks")
    private let manager: CoreDataManager

    init(manager: CoreDataManager = .shared) {
        self.manager = manager
    }

    // MARK: - Load

    func load() -> StreakSnapshot? {
        let context = manager.viewContext

        var activities: [DailyActivity] = []
        var currentStreak = 0
        var longestStreak = 0
        var lastCountedDay: Date?

        context.performAndWait {
            let storedActivities = (try? context.fetch(
                Self.activityRequest()
            )) ?? []
            activities = storedActivities.compactMap(Self.toActivity)

            let meta = (try? context.fetch(Self.metaRequest()))?.first
            currentStreak = meta?.value(forKey: "currentStreak") as? Int ?? 0
            longestStreak = meta?.value(forKey: "longestStreak") as? Int ?? 0
            lastCountedDay = meta?.value(forKey: "lastCountedDay") as? Date
        }

        guard !activities.isEmpty || currentStreak > 0 || longestStreak > 0 else { return nil }

        return StreakSnapshot(
            activities: activities,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastCountedDay: lastCountedDay
        )
    }

    // MARK: - Save

    func save(_ snapshot: StreakSnapshot) {
        let context = manager.viewContext
        context.performAndWait { [logger] in
            // Replace all activities
            self.deleteAllActivities(in: context)
            for activity in snapshot.activities {
                Self.insert(activity, into: context)
            }

            // Upsert streak metadata (singleton row)
            let meta = self.findOrCreateMeta(in: context)
            meta.setValue(Int32(snapshot.currentStreak), forKey: "currentStreak")
            meta.setValue(Int32(snapshot.longestStreak), forKey: "longestStreak")
            meta.setValue(snapshot.lastCountedDay, forKey: "lastCountedDay")

            do {
                try context.save()
            } catch {
                logger.error("Failed to save streak snapshot — \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Helpers

    private static func activityRequest() -> NSFetchRequest<NSManagedObject> {
        NSFetchRequest<NSManagedObject>(entityName: CDEntity.dailyActivity)
    }

    private static func metaRequest() -> NSFetchRequest<NSManagedObject> {
        NSFetchRequest<NSManagedObject>(entityName: CDEntity.streakMeta)
    }

    private static func toActivity(_ object: NSManagedObject) -> DailyActivity? {
        guard let date = object.value(forKey: "date") as? Date,
              let hasMeditation = object.value(forKey: "hasMeditation") as? Bool,
              let hasNote = object.value(forKey: "hasNote") as? Bool else {
            return nil
        }
        return DailyActivity(
            date: date,
            hasMeditation: hasMeditation,
            hasNote: hasNote
        )
    }

    private func deleteAllActivities(in context: NSManagedObjectContext) {
        // Plain object deletes (not NSBatchDeleteRequest) so this works on both
        // the disk-backed store and the in-memory store used by tests.
        if let existing = try? context.fetch(Self.activityRequest()) {
            for object in existing {
                context.delete(object)
            }
        }
    }

    private static func insert(_ activity: DailyActivity, into context: NSManagedObjectContext) {
        let object = NSEntityDescription.insertNewObject(forEntityName: CDEntity.dailyActivity, into: context)
        object.setValue(activity.date, forKey: "date")
        object.setValue(activity.hasMeditation, forKey: "hasMeditation")
        object.setValue(activity.hasNote, forKey: "hasNote")
    }

    private func findOrCreateMeta(in context: NSManagedObjectContext) -> NSManagedObject {
        if let existing = try? context.fetch(Self.metaRequest()).first {
            return existing
        }
        return NSEntityDescription.insertNewObject(forEntityName: CDEntity.streakMeta, into: context)
    }
}