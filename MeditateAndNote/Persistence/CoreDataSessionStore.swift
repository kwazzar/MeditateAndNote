//
//  CoreDataSessionStore.swift
//  MeditateAndNote
//
//  Core Data implementation of MeditationSessionStoring.
//

@preconcurrency import CoreData
import Foundation
import OSLog

@Observable
final class CoreDataSessionStore {

    private let logger = Logger(subsystem: Config.bundleID, category: "CoreDataSessions")
    private let manager: CoreDataManager

    init(manager: CoreDataManager = .shared) {
        self.manager = manager
    }

    // MARK: - Save

    func save(_ session: MeditationSession) async {
        let context = manager.viewContext
        await context.perform { [logger] in
            let object = NSEntityDescription.insertNewObject(forEntityName: CDEntity.session, into: context)
            object.setValue(session.id.rawValue, forKey: "id")
            object.setValue(session.meditationId.rawValue, forKey: "meditationId")
            object.setValue(session.completedAt, forKey: "completedAt")
            object.setValue(session.duration.seconds, forKey: "duration")
            do {
                try context.save()
            } catch {
                logger.error("Failed to save meditation session — \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Fetch for Date

    func sessions(for date: Date) async -> [MeditationSession] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = NSPredicate(
            format: "completedAt >= %@ AND completedAt < %@",
            start as NSDate,
            end as NSDate
        )
        return await fetch(predicate: predicate)
    }

    // MARK: - All Session Dates

    func allSessionDates() async -> Set<Date> {
        let all = await fetch(predicate: nil)
        let calendar = Calendar.current
        return Set(all.map { calendar.startOfDay(for: $0.completedAt) })
    }

    // MARK: - Private Helpers

    private func fetch(predicate: NSPredicate?) async -> [MeditationSession] {
        let context = manager.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.session)
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]

        return await context.perform {
            let stored = (try? context.fetch(request)) ?? []
            return stored.compactMap(Self.toSession)
        }
    }

    /// Maps a stored row to a domain session, skipping rows whose typed
    /// values are corrupted rather than crashing the whole lookup.
    private static func toSession(_ object: NSManagedObject) -> MeditationSession? {
        guard let id = object.value(forKey: "id") as? UUID,
              let meditationId = object.value(forKey: "meditationId") as? String,
              let completedAt = object.value(forKey: "completedAt") as? Date,
              let rawDuration = object.value(forKey: "duration") as? TimeInterval,
              rawDuration > 0 else {
            return nil
        }
        return MeditationSession(
            id: SessionID(rawValue: id),
            meditationId: MeditationID(rawValue: meditationId),
            completedAt: completedAt,
            duration: SessionDuration(seconds: rawDuration)
        )
    }
}

// MARK: - Domain Event Subscription

extension CoreDataSessionStore {
    func handle(_ event: DomainEvent) async {
        switch event {
        case .noteCreated, .noteUpdated, .noteDeleted:
            break

        case let .meditationCompleted(session):
            await save(session)
        }
    }
}
