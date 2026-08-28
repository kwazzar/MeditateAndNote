//
//  CoreDataNoteDataSource.swift
//  MeditateAndNote
//
//  Core Data implementation of NoteDataSource.
//

import CoreData
import Foundation
import OSLog

final class CoreDataNoteDataSource: NoteDataSource {

    typealias Item = Note

    private let logger = Logger(subsystem: Config.bundleID, category: "CoreDataNotes")
    private let manager: CoreDataManager

    init(manager: CoreDataManager = .shared) {
        self.manager = manager
    }

    // MARK: - Fetch All

    func fetchAll() async throws -> [Note] {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.note)
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

            let results = try context.fetch(request)
            return results.map(Self.toNote)
        }
    }

    // MARK: - Fetch by ID

    func fetch(id: NoteID) async throws -> Note? {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.note)
            request.predicate = NSPredicate(format: "id == %@", id.rawValue as CVarArg)
            request.fetchLimit = 1

            let result = try context.fetch(request).first
            return result.map(Self.toNote)
        }
    }

    // MARK: - Save (upsert)

    func save(_ note: Note) async throws {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let object = Self.findOrCreate(id: note.id, in: context)
            Self.apply(note, to: object)
            try context.save()
        }
    }

    // MARK: - Delete

    func delete(id: NoteID) async throws {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.note)
            request.predicate = NSPredicate(format: "id == %@", id.rawValue as CVarArg)
            request.fetchLimit = 1

            if let object = try context.fetch(request).first {
                context.delete(object)
                try context.save()
            }
        }
    }

    // MARK: - Delete All

    func deleteAll() async throws {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.note)
            for object in try context.fetch(request) {
                context.delete(object)
            }
            try context.save()
        }
    }

    // MARK: - Mapping Helpers

    private static func toNote(_ object: NSManagedObject) -> Note {
        Note(
            id: NoteID(rawValue: object.value(forKey: "id") as! UUID),
            title: NoteTitle(object.value(forKey: "title") as! String),
            content: NoteContent(object.value(forKey: "content") as! String),
            date: object.value(forKey: "date") as! Date
        )
    }

    private static func apply(_ note: Note, to object: NSManagedObject) {
        object.setValue(note.id.rawValue, forKey: "id")
        object.setValue(note.title.rawValue, forKey: "title")
        object.setValue(note.content.rawValue, forKey: "content")
        object.setValue(note.date, forKey: "date")
    }

    private static func findOrCreate(id: NoteID, in context: NSManagedObjectContext) -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.note)
        request.predicate = NSPredicate(format: "id == %@", id.rawValue as CVarArg)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }
        return NSEntityDescription.insertNewObject(forEntityName: CDEntity.note, into: context)
    }
}
