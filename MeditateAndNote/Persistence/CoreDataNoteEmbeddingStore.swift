//
//  CoreDataNoteEmbeddingStore.swift
//  MeditateAndNote
//
//  Core Data implementation of NoteEmbeddingStore. One row per note; the
//  vector is stored as raw binary Data and the content hash as a scalar for
//  cheap staleness checks. NSManagedObject never leaks.
//

import CoreData
import Foundation
import OSLog

final class CoreDataNoteEmbeddingStore: NoteEmbeddingStore {

    private let logger = Logger(subsystem: Config.bundleID, category: "CoreDataNoteEmbedding")
    nonisolated(unsafe) private let manager: CoreDataManager

    init(manager: CoreDataManager = .shared) {
        self.manager = manager
    }

    func fetchAll() async throws -> [NoteEmbedding] {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.noteEmbedding)

            let results = try context.fetch(request)
            return results.compactMap(Self.toEmbedding)
        }
    }

    func fetch(noteID: NoteID) async throws -> NoteEmbedding? {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.noteEmbedding)
            request.predicate = NSPredicate(format: "noteID == %@", noteID.rawValue as CVarArg)
            request.fetchLimit = 1

            return try context.fetch(request).first.flatMap(Self.toEmbedding)
        }
    }

    func save(_ embedding: NoteEmbedding) async throws {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let object = Self.findOrCreate(noteID: embedding.noteID, in: context)
            Self.apply(embedding, to: object)
            try context.save()
        }
    }

    func delete(noteID: NoteID) async throws {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.noteEmbedding)
            request.predicate = NSPredicate(format: "noteID == %@", noteID.rawValue as CVarArg)

            for object in try context.fetch(request) {
                context.delete(object)
            }
            try context.save()
        }
    }

    func deleteAll() async throws {
        try await manager.viewContext.perform { [context = manager.viewContext] in
            let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.noteEmbedding)
            for object in try context.fetch(request) {
                context.delete(object)
            }
            try context.save()
        }
    }

    // MARK: - Mapping Helpers

    private static func toEmbedding(_ object: NSManagedObject) -> NoteEmbedding? {
        guard let noteID = object.value(forKey: "noteID") as? UUID,
              let vectorData = object.value(forKey: "vector") as? Data,
              let hash = object.value(forKey: "contentHash") as? Int64,
              let updatedAt = object.value(forKey: "updatedAt") as? Date,
              let array = decode(vectorData) else {
            return nil
        }
        return NoteEmbedding(
            noteID: NoteID(rawValue: noteID),
            vector: array,
            contentHash: UInt64(bitPattern: hash),
            updatedAt: updatedAt
        )
    }

    private static func apply(_ embedding: NoteEmbedding, to object: NSManagedObject) {
        object.setValue(embedding.noteID.rawValue, forKey: "noteID")
        object.setValue(encode(embedding.vector), forKey: "vector")
        object.setValue(Int64(bitPattern: embedding.contentHash), forKey: "contentHash")
        object.setValue(embedding.updatedAt, forKey: "updatedAt")
    }

    private static func findOrCreate(noteID: NoteID, in context: NSManagedObjectContext) -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: CDEntity.noteEmbedding)
        request.predicate = NSPredicate(format: "noteID == %@", noteID.rawValue as CVarArg)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }
        return NSEntityDescription.insertNewObject(forEntityName: CDEntity.noteEmbedding, into: context)
    }

    private static func encode(_ vector: [Float]) -> Data? {
        vector.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    private static func decode(_ data: Data) -> [Float]? {
        guard data.count % MemoryLayout<Float>.size == 0 else { return nil }
        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }
}