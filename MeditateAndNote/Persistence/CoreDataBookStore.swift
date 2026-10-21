//
//  CoreDataBookStore.swift
//  MeditateAndNote
//
//  Core Data implementation of BookStore.
//

@preconcurrency import CoreData
import Foundation
import MeditateAndNoteCore

final class CoreDataBookStore: BookStore, @unchecked Sendable {

    private let logger = Logger(subsystem: Config.bundleID, category: "CoreDataBooks")
    private let manager: CoreDataManager

    init(manager: CoreDataManager = .shared) {
        self.manager = manager
    }

    // MARK: - Books

    func fetchAll() async throws -> [Book] {
        let context = manager.viewContext
        return try await context.perform {
            let objects = try context.fetch(Self.request())
            return objects.compactMap(Self.toBook)
        }
    }

    func fetch(id: BookID) async throws -> Book? {
        let context = manager.viewContext
        return try await context.perform {
            try Self.find(id: id, in: context).flatMap(Self.toBook)
        }
    }

    func save(_ book: Book) async throws {
        let context = manager.viewContext
        try await context.perform {
            let object = try Self.findOrCreate(id: book.id, in: context)
            Self.apply(book, to: object)
            try context.save()
        }
    }

    func delete(id: BookID) async throws {
        let context = manager.viewContext
        try await context.perform {
            if let object = try Self.find(id: id, in: context) {
                context.delete(object)
                try context.save()
            }
        }
    }

    func deleteAll() async throws {
        let context = manager.viewContext
        try await context.perform {
            for object in try context.fetch(Self.request()) {
                context.delete(object)
            }
            try context.save()
        }
    }

    // MARK: - Reading position

    func readingPosition(for bookID: BookID) async throws -> ReadingPosition? {
        let context = manager.viewContext
        return try await context.perform {
            guard let object = try Self.find(id: bookID, in: context) else { return nil }
            return ReadingPosition(
                chapterIndex: object.value(forKey: "positionChapter") as? Int ?? 0,
                blockIndex: object.value(forKey: "positionBlock") as? Int ?? 0,
                characterOffset: object.value(forKey: "positionOffset") as? Int ?? 0
            )
        }
    }

    func saveReadingPosition(_ position: ReadingPosition, for bookID: BookID) async throws {
        let context = manager.viewContext
        try await context.perform {
            guard let object = try Self.find(id: bookID, in: context) else { return }
            object.setValue(Int32(position.chapterIndex), forKey: "positionChapter")
            object.setValue(Int32(position.blockIndex), forKey: "positionBlock")
            object.setValue(Int32(position.characterOffset), forKey: "positionOffset")
            try context.save()
        }
    }

    // MARK: - Cover

    func coverData(for bookID: BookID) async throws -> Data? {
        let context = manager.viewContext
        return try await context.perform {
            try Self.find(id: bookID, in: context)?.value(forKey: "coverData") as? Data
        }
    }

    func saveCoverData(_ data: Data?, for bookID: BookID) async throws {
        let context = manager.viewContext
        try await context.perform {
            guard let object = try Self.find(id: bookID, in: context) else { return }
            object.setValue(data, forKey: "coverData")
            try context.save()
        }
    }

    // MARK: - Mapping

    private static func request() -> NSFetchRequest<NSManagedObject> {
        NSFetchRequest<NSManagedObject>(entityName: CDEntity.book)
    }

    private static func find(id: BookID, in context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = request()
        request.predicate = NSPredicate(format: "id == %@", id.rawValue as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func findOrCreate(id: BookID, in context: NSManagedObjectContext) throws -> NSManagedObject {
        if let existing = try find(id: id, in: context) {
            return existing
        }
        return NSEntityDescription.insertNewObject(forEntityName: CDEntity.book, into: context)
    }

    private static func apply(_ book: Book, to object: NSManagedObject) {
        object.setValue(book.id.rawValue, forKey: "id")
        object.setValue(book.title, forKey: "title")
        object.setValue(book.author, forKey: "author")
        object.setValue(book.format.rawValue, forKey: "formatRaw")
        object.setValue(book.fileName, forKey: "fileName")
        object.setValue(book.addedAt, forKey: "addedAt")
        object.setValue(book.lastOpenedAt, forKey: "lastOpenedAt")
    }

    private static func toBook(_ object: NSManagedObject) -> Book? {
        guard let id = object.value(forKey: "id") as? UUID,
              let title = object.value(forKey: "title") as? String,
              let formatRaw = object.value(forKey: "formatRaw") as? String,
              let format = BookFormat(rawValue: formatRaw),
              let fileName = object.value(forKey: "fileName") as? String,
              let addedAt = object.value(forKey: "addedAt") as? Date else {
            return nil
        }
        return Book(
            id: BookID(rawValue: id),
            title: title,
            author: object.value(forKey: "author") as? String,
            format: format,
            fileName: fileName,
            addedAt: addedAt,
            lastOpenedAt: object.value(forKey: "lastOpenedAt") as? Date
        )
    }
}

// MARK: - InMemoryBookStore

actor InMemoryBookStore: BookStore {
    private var books: [BookID: Book] = [:]
    private var positions: [BookID: ReadingPosition] = [:]
    private var covers: [BookID: Data] = [:]

    init(books: [Book] = []) {
        for book in books {
            self.books[book.id] = book
        }
    }

    func fetchAll() async throws -> [Book] {
        books.values.sorted { $0.addedAt > $1.addedAt }
    }

    func fetch(id: BookID) async throws -> Book? {
        books[id]
    }

    func save(_ book: Book) async throws {
        books[book.id] = book
    }

    func delete(id: BookID) async throws {
        books[id] = nil
        positions[id] = nil
        covers[id] = nil
    }

    func deleteAll() async throws {
        books.removeAll()
        positions.removeAll()
        covers.removeAll()
    }

    func readingPosition(for bookID: BookID) async throws -> ReadingPosition? {
        positions[bookID]
    }

    func saveReadingPosition(_ position: ReadingPosition, for bookID: BookID) async throws {
        positions[bookID] = position
    }

    func coverData(for bookID: BookID) async throws -> Data? {
        covers[bookID]
    }

    func saveCoverData(_ data: Data?, for bookID: BookID) async throws {
        covers[bookID] = data
    }
}
