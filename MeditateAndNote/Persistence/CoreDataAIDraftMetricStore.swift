//
//  CoreDataAIDraftMetricStore.swift
//  MeditateAndNote
//
//  Core Data implementation of AIDraftMetricStore. Each row is one
//  append-only telemetry event: kind scalar for cheap rollups, payload as a
//  typed JSON blob for round-tripping. NSManagedObject never leaks here.
//

import CoreData
import Foundation
import OSLog

final class CoreDataAIDraftMetricStore: AIDraftMetricStore {

    private let logger = Logger(subsystem: Config.bundleID, category: "CoreDataAIDraftMetrics")
    nonisolated(unsafe) private let manager: CoreDataManager

    init(manager: CoreDataManager = .shared) {
        self.manager = manager
    }

    func record(_ metric: AIDraftMetric) async throws {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let object = NSEntityDescription.insertNewObject(
                forEntityName: CDEntity.aiDraftMetric,
                into: context
            )
            object.setValue(UUID(), forKey: "id")
            object.setValue(metric.kindRawValue, forKey: "kind")
            object.setValue(try? JSONEncoder().encode(metric), forKey: "payloadJSON")
            object.setValue(Date(), forKey: "recordedAt")
            try context.save()
        }
    }

    func fetchAll() async throws -> [AIDraftMetric] {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.aiDraftMetric)
            request.sortDescriptors = [NSSortDescriptor(key: "recordedAt", ascending: true)]

            let results = try context.fetch(request)
            return results.compactMap(Self.toMetric)
        }
    }

    func deleteAll() async throws {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.aiDraftMetric)
            for object in try context.fetch(request) {
                context.delete(object)
            }
            try context.save()
        }
    }

    // MARK: - Mapping Helpers

    private static func toMetric(_ object: NSManagedObject) -> AIDraftMetric? {
        guard let data = object.value(forKey: "payloadJSON") as? Data else { return nil }
        return try? JSONDecoder().decode(AIDraftMetric.self, from: data)
    }
}