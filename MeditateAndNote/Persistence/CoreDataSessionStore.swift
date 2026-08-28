//
//  CoreDataSessionStore.swift
//  MeditateAndNote
//
//  Core Data implementation of MeditationSessionStoring.
//

import CoreData
import Foundation
import OSLog

@Observable
final class CoreDataSessionStore: MeditationSessionStoring {

    private let logger = Logger(subsystem: Config.bundleID, category: "CoreDataSessions")
    private let manager: CoreDataManager

    init(manager: CoreDataManager = .shared) {
        self.manager = manager
    }

    // MARK: - Save

    func save(_ session: MeditationSession) {
        let context = manager.viewContext
        context.performAndWait { [logger] in
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

    func sessions(for date: Date) -> [MeditationSession] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = NSPredicate(
            format: "completedAt >= %@ AND completedAt < %@",
            start as NSDate,
            end as NSDate
        )
        return fetch(predicate: predicate)
    }

    // MARK: - All Session Dates

    func allSessionDates() -> Set<Date> {
        let all = fetch(predicate: nil)
        let calendar = Calendar.current
        return Set(all.map { calendar.startOfDay(for: $0.completedAt) })
    }

    // MARK: - Private Helpers

    private func fetch(predicate: NSPredicate?) -> [MeditationSession] {
        let context = manager.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.session)
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]

        var results: [MeditationSession] = []
        context.performAndWait {
            let stored = (try? context.fetch(request)) ?? []
            results = stored.map(Self.toSession)
        }
        return results
    }

    private static func toSession(_ object: NSManagedObject) -> MeditationSession {
        MeditationSession(
            id: SessionID(rawValue: object.value(forKey: "id") as! UUID),
            meditationId: MeditationID(rawValue: object.value(forKey: "meditationId") as! String),
            completedAt: object.value(forKey: "completedAt") as! Date,
            duration: SessionDuration(seconds: object.value(forKey: "duration") as! TimeInterval)
        )
    }
}

// MARK: - Domain Event Subscription

extension CoreDataSessionStore {
    func handle(_ event: DomainEvent) {
        switch event {
        case .noteCreated, .noteUpdated, .noteDeleted:
            break

        case let .meditationCompleted(session):
            save(session)
        }
    }
}
