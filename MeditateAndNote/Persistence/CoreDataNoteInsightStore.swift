//
//  CoreDataNoteInsightStore.swift
//  MeditateAndNote
//
//  Core Data implementation of NoteInsightStore. One row per note (noteID is
//  unique): themes and tags are stored as JSON blobs of the domain value
//  types, with scalar attributes for querying. NSManagedObject never leaks.
//

import CoreData
import Foundation
import OSLog

final class CoreDataNoteInsightStore: NoteInsightStore {

    private let logger = Logger(subsystem: Config.bundleID, category: "CoreDataNoteInsight")
    nonisolated(unsafe) private let manager: CoreDataManager

    init(manager: CoreDataManager = .shared) {
        self.manager = manager
    }

    func fetchAll() async throws -> [NoteInsight] {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.noteInsight)
            request.sortDescriptors = [NSSortDescriptor(key: "generatedAt", ascending: false)]

            let results = try context.fetch(request)
            return results.compactMap(Self.toInsight)
        }
    }

    func fetch(noteID: NoteID) async throws -> NoteInsight? {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.noteInsight)
            request.predicate = NSPredicate(format: "noteID == %@", noteID.rawValue as CVarArg)
            request.fetchLimit = 1

            return try context.fetch(request).first.flatMap(Self.toInsight)
        }
    }

    func save(_ insight: NoteInsight) async throws {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let object = Self.findOrCreate(noteID: insight.noteID, in: context)
            Self.apply(insight, to: object)
            try context.save()
        }
    }

    func delete(noteID: NoteID) async throws {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.noteInsight)
            request.predicate = NSPredicate(format: "noteID == %@", noteID.rawValue as CVarArg)

            for object in try context.fetch(request) {
                context.delete(object)
            }
            try context.save()
        }
    }

    func deleteAll() async throws {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.noteInsight)
            for object in try context.fetch(request) {
                context.delete(object)
            }
            try context.save()
        }
    }

    // MARK: - Mapping Helpers

    private static func toInsight(_ object: NSManagedObject) -> NoteInsight? {
        guard let noteID = object.value(forKey: "noteID") as? UUID,
              let themesData = object.value(forKey: "themesJSON") as? Data,
              let summary = object.value(forKey: "summary") as? String,
              let tagsData = object.value(forKey: "tagsJSON") as? Data,
              let generatedAt = object.value(forKey: "generatedAt") as? Date,
              let themes = try? JSONDecoder().decode([NoteTheme].self, from: themesData),
              let tags = try? JSONDecoder().decode([String].self, from: tagsData) else {
            return nil
        }
        return NoteInsight(
            noteID: NoteID(rawValue: noteID),
            themes: themes,
            summary: summary,
            suggestedTags: tags,
            generatedAt: generatedAt
        )
    }

    private static func apply(_ insight: NoteInsight, to object: NSManagedObject) {
        object.setValue(insight.noteID.rawValue, forKey: "noteID")
        object.setValue(try? JSONEncoder().encode(insight.themes), forKey: "themesJSON")
        object.setValue(insight.summary, forKey: "summary")
        object.setValue(try? JSONEncoder().encode(insight.suggestedTags), forKey: "tagsJSON")
        object.setValue(insight.generatedAt, forKey: "generatedAt")
    }

    private static func findOrCreate(noteID: NoteID, in context: NSManagedObjectContext) -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.noteInsight)
        request.predicate = NSPredicate(format: "noteID == %@", noteID.rawValue as CVarArg)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }
        return NSEntityDescription.insertNewObject(forEntityName: CDEntity.noteInsight, into: context)
    }
}
