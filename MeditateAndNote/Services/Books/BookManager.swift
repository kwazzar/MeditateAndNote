//
//  BookManager.swift
//  MeditateAndNote
//
//  Application Service: orchestrates Book use cases
//  (import, library, reading position, content loading).
//

import Foundation
import MeditateAndNoteCore

// MARK: - Errors

enum BookImportError: Error {
    case unsupportedFile
    case unreadable(String)
}

enum BookOperationError: Error {
    case loadFailed
    case saveFailed
    case deleteFailed
}

// MARK: - Protocols for ViewModels

protocol BookProvidable: Sendable {
    func refresh() async
    var currentBooks: [Book] { get async }
    func book(with id: BookID) async throws -> Book?
    func progress(for id: BookID) async -> Double
    func coverData(for id: BookID) async -> Data?
    func loadContent(for id: BookID) async throws -> (Book, BookContent, ReadingPosition)
}

protocol BookManageable: Sendable {
    func importBook(from url: URL) async throws -> Book
    func delete(with id: BookID) async throws
    func saveReadingPosition(_ position: ReadingPosition, for id: BookID) async throws
    func markOpened(_ id: BookID) async throws
}

// MARK: - Book Manager (Application Service)

final actor BookManager: BookProvidable, BookManageable {
    private let logger = Logger(subsystem: Config.bundleID, category: "BookManager")
    private let store: any BookStore
    private let fileStorage: BookFileStorage

    private var library: [Book] = []

    init(store: any BookStore, fileStorage: BookFileStorage = BookFileStorage()) {
        self.store = store
        self.fileStorage = fileStorage
    }

    // MARK: - BookProvidable

    func refresh() async {
        do {
            library = try await store.fetchAll()
        } catch {
            logger.error("Failed to fetch books — \(error.localizedDescription)")
        }
    }

    var currentBooks: [Book] { library }

    func book(with id: BookID) async throws -> Book? {
        try await store.fetch(id: id)
    }

    func progress(for id: BookID) async -> Double {
        guard let book = try? await store.fetch(id: id),
              let position = try? await store.readingPosition(for: id) else {
            return 0
        }
        guard let content = try? Self.parseContent(for: book, fileStorage: fileStorage) else {
            return 0
        }
        return content.content.progress(of: position)
    }

    func coverData(for id: BookID) async -> Data? {
        (try? await store.coverData(for: id)) ?? nil
    }

    // MARK: - BookManageable

    func importBook(from url: URL) async throws -> Book {
        let format = Self.detectFormat(url: url)
        guard let format else { throw BookImportError.unsupportedFile }

        let bookID = BookID()
        let fileName = try fileStorage.importBook(from: url, id: bookID, format: format)

        var book = Book(
            id: bookID,
            title: url.deletingPathExtension().lastPathComponent,
            format: format,
            fileName: fileName
        )

        // Extract metadata + cover eagerly so the library shows them;
        // full parse happens lazily when the reader opens the book.
        if let parsed = try? Self.parseContent(for: book, fileStorage: fileStorage) {
            if let title = parsed.content.title, !title.isEmpty { book.title = title }
            book.author = parsed.content.author
            try await store.save(book)
            if let cover = parsed.coverData {
                try? await store.saveCoverData(cover, for: bookID)
            }
        }
        try await store.save(book)
        await refresh()
        return book
    }

    func delete(with id: BookID) async throws {
        guard let book = try await store.fetch(id: id) else {
            throw BookOperationError.deleteFailed
        }
        fileStorage.deleteBook(book)
        try await store.delete(id: id)
        await refresh()
    }

    func saveReadingPosition(_ position: ReadingPosition, for id: BookID) async throws {
        try await store.saveReadingPosition(position, for: id)
    }

    func markOpened(_ id: BookID) async throws {
        guard var book = try await store.fetch(id: id) else { return }
        book.lastOpenedAt = Date()
        try await store.save(book)
        await refresh()
    }

    // MARK: - Content loading (reader support)

    /// Parses the full book content for the reader.
    /// `position` restores the saved position clamped to the parsed content.
    func loadContent(for id: BookID) async throws -> (Book, BookContent, ReadingPosition) {
        guard let book = try await store.fetch(id: id) else {
            throw BookOperationError.loadFailed
        }
        guard let parsed = try? Self.parseContent(for: book, fileStorage: fileStorage) else {
            throw BookOperationError.loadFailed
        }
        let saved = (try? await store.readingPosition(for: id)) ?? ReadingPosition()
        let restored = saved.clamped(to: parsed.content)
        return (book, parsed.content, restored)
    }

    // MARK: - Helpers

    static func detectFormat(url: URL) -> BookFormat? {
        BookFormat(rawValue: url.pathExtension.lowercased())
    }

    private static func parseContent(for book: Book, fileStorage: BookFileStorage) throws -> (content: BookContent, coverData: Data?) {
        switch book.format {
        case .fb2:
            let data = try fileStorage.loadData(for: book)
            let result = try FB2Parser().parse(data)
            return (result.content, result.coverData)
        case .epub:
            let loader = fileStorage.entryLoader(for: book)
            let result = try EPUBParser().parse(fileAccessor: loader)
            return (result.content, result.coverData)
        case .txt:
            let data = try fileStorage.loadData(for: book)
            let content = TXTParser().parse(data, title: book.title)
            return (content, nil)
        }
    }
}
