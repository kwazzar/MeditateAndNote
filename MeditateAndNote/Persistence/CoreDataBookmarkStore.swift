//
//  CoreDataBookmarkStore.swift
//  MeditateAndNote
//
//  Core Data implementation of BookmarkStore.
//

@preconcurrency import CoreData
import Foundation
import MeditateAndNoteCore

final class CoreDataBookmarkStore: BookmarkStore, @unchecked Sendable {

    private let logger = Logger(subsystem: Config.bundleID, category: "CoreDataBookmarks")
    private let manager: CoreDataManager

    init(manager: CoreDataManager = .shared) {
        self.manager = manager
    }

    // MARK: - Read

    func fetchAll(bookID: BookID) async throws -> [Bookmark] {
        let context = manager.viewContext
        return try await context.perform {
            let request = Self.request()
            request.predicate = NSPredicate(format: "bookID == %@", bookID.rawValue as CVarArg)
            let objects = try context.fetch(request)
            return objects.compactMap(Self.toBookmark)
        }
    }

    func fetch(id: BookmarkID) async throws -> Bookmark? {
        let context = manager.viewContext
        return try await context.perform {
            try Self.find(id: id, in: context).flatMap(Self.toBookmark)
        }
    }

    // MARK: - Write

    func save(_ bookmark: Bookmark) async throws {
        let context = manager.viewContext
        try await context.perform {
            let object = try Self.findOrCreate(id: bookmark.id, in: context)
            Self.apply(bookmark, to: object)
            try context.save()
        }
    }

    func delete(id: BookmarkID) async throws {
        let context = manager.viewContext
        try await context.perform {
            if let object = try Self.find(id: id, in: context) {
                context.delete(object)
                try context.save()
            }
        }
    }

    func deleteAll(bookID: BookID) async throws {
        let context = manager.viewContext
        try await context.perform {
            let request = Self.request()
            request.predicate = NSPredicate(format: "bookID == %@", bookID.rawValue as CVarArg)
            for object in try context.fetch(request) {
                context.delete(object)
            }
            try context.save()
        }
    }

    // MARK: - Mapping

    private static func request() -> NSFetchRequest<NSManagedObject> {
        NSFetchRequest<NSManagedObject>(entityName: CDEntity.bookmark)
    }

    private static func find(id: BookmarkID, in context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = request()
        request.predicate = NSPredicate(format: "id == %@", id.rawValue as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func findOrCreate(id: BookmarkID, in context: NSManagedObjectContext) throws -> NSManagedObject {
        if let existing = try find(id: id, in: context) {
            return existing
        }
        return NSEntityDescription.insertNewObject(forEntityName: CDEntity.bookmark, into: context)
    }

    private static func apply(_ bookmark: Bookmark, to object: NSManagedObject) {
        object.setValue(bookmark.id.rawValue, forKey: "id")
        object.setValue(bookmark.bookID.rawValue, forKey: "bookID")
        object.setValue(Int32(bookmark.position.chapterIndex), forKey: "positionChapter")
        object.setValue(Int32(bookmark.position.blockIndex), forKey: "positionBlock")
        object.setValue(Int32(bookmark.position.characterOffset), forKey: "positionOffset")
        object.setValue(bookmark.text, forKey: "text")
        object.setValue(bookmark.noteID?.rawValue, forKey: "noteID")
        object.setValue(bookmark.createdAt, forKey: "createdAt")
    }

    private static func toBookmark(_ object: NSManagedObject) -> Bookmark? {
        guard let id = object.value(forKey: "id") as? UUID,
              let bookID = object.value(forKey: "bookID") as? UUID,
              let createdAt = object.value(forKey: "createdAt") as? Date else {
            return nil
        }
        let position = ReadingPosition(
            chapterIndex: object.value(forKey: "positionChapter") as? Int ?? 0,
            blockIndex: object.value(forKey: "positionBlock") as? Int ?? 0,
            characterOffset: object.value(forKey: "positionOffset") as? Int ?? 0
        )
        let noteID = (object.value(forKey: "noteID") as? UUID).map(NoteID.init(rawValue:))
        return Bookmark(
            id: BookmarkID(rawValue: id),
            bookID: BookID(rawValue: bookID),
            position: position,
            text: object.value(forKey: "text") as? String,
            noteID: noteID,
            createdAt: createdAt
        )
    }
}

// MARK: - InMemoryBookmarkStore

actor InMemoryBookmarkStore: BookmarkStore {
    private var bookmarks: [BookmarkID: Bookmark] = [:]

    init(bookmarks: [Bookmark] = []) {
        for bookmark in bookmarks {
            self.bookmarks[bookmark.id] = bookmark
        }
    }

    func fetchAll(bookID: BookID) async throws -> [Bookmark] {
        bookmarks.values
            .filter { $0.bookID == bookID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func fetch(id: BookmarkID) async throws -> Bookmark? {
        bookmarks[id]
    }

    func save(_ bookmark: Bookmark) async throws {
        bookmarks[bookmark.id] = bookmark
    }

    func delete(id: BookmarkID) async throws {
        bookmarks[id] = nil
    }

    func deleteAll(bookID: BookID) async throws {
        for (id, bookmark) in bookmarks where bookmark.bookID == bookID {
            bookmarks[id] = nil
        }
    }
}
