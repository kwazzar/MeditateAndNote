//
//  KotlinBookStore.swift
//  MeditateAndNoteCoreJNI
//
//  A `BookStore` that persists through Kotlin's SharedPreferences, plus the
//  book-file and pagination entry points the Android reader needs.
//
//  Same division of labour as `KotlinStreakActivityStore`: Swift owns the
//  bytes, Kotlin owns the storage. The library is one JSON array document;
//  positions and covers are per-book keys. Book files are copied by Kotlin
//  into `filesDir/books/` and read back by Swift directly (same process), so
//  `loadData` needs no JNI traffic for large files.
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

/// The Kotlin object's JVM class. Bound to `BookBlobStore`.
@JavaClass("com.mn.android.data.BookBlobStore")
public class BookBlobStore: JavaObject {}

/// The Kotlin `TextMetrics` object used as the Android `TextMeasurer`.
@JavaClass("com.mn.android.data.TextMetrics")
public class KotlinTextMetrics: JavaObject {}

/// SharedPreferences-backed implementation of `BookStore`.
public struct KotlinBookStore: BookStore {

    static let logger = Logger(subsystem: "com.mn.core", category: "BookStore")

    public init() {}

    // MARK: - Library

    public func fetchAll() async throws -> [Book] {
        try librarySync()
    }

    public func fetch(id: BookID) async throws -> Book? {
        try librarySync().first { $0.id == id }
    }

    public func save(_ book: Book) async throws {
        try saveSync(book)
    }

    public func delete(id: BookID) async throws {
        try deleteSync(id)
    }

    public func deleteAll() async throws {
        for book in try librarySync() {
            try deleteSync(book.id)
        }
    }

    // MARK: - Position

    public func readingPosition(for bookID: BookID) async throws -> ReadingPosition? {
        do { return try positionSync(for: bookID) } catch {
            Self.logger.warning("BookStore.readingPosition failed: \(error)")
            return nil
        }
    }

    public func saveReadingPosition(_ position: ReadingPosition, for bookID: BookID) async throws {
        do {
            let json = String(decoding: try JSONEncoder().encode(position), as: UTF8.self)
            try callSavePosition(id: bookID.rawValue.uuidString, json: json)
        } catch {
            Self.logger.warning("BookStore.saveReadingPosition failed: \(error)")
        }
    }

    // MARK: - Cover

    public func coverData(for bookID: BookID) async throws -> Data? {
        do {
            let base64 = try callLoadCover(id: bookID.rawValue.uuidString)
            guard !base64.isEmpty else { return nil }
            return Data(base64Encoded: base64)
        } catch {
            Self.logger.warning("BookStore.coverData failed: \(error)")
            return nil
        }
    }

    public func saveCoverData(_ data: Data?, for bookID: BookID) async throws {
        do {
            try callSaveCover(id: bookID.rawValue.uuidString, base64: data?.base64EncodedString() ?? "")
        } catch {
            Self.logger.warning("BookStore.saveCoverData failed: \(error)")
        }
    }

    // MARK: - Synchronous core

    func librarySync() throws -> [Book] {
        let json = try callLoadLibrary()
        guard !json.isEmpty else { return [] }
        return try JSONDecoder().decode([Book].self, from: Data(json.utf8))
    }

    func saveSync(_ book: Book) throws {
        var books = try librarySync()
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = book
        } else {
            books.append(book)
        }
        try writeLibrary(books)
    }

    func deleteSync(_ id: BookID) throws {
        let books = try librarySync()
        let remaining = books.filter { $0.id != id }
        try writeLibrary(remaining)
        try callClearBookData(id: id.rawValue.uuidString)
        if let book = books.first(where: { $0.id == id }) {
            try callDeleteFile(path: book.fileName)
        }
    }

    func positionSync(for bookID: BookID) throws -> ReadingPosition? {
        let json = try callLoadPosition(id: bookID.rawValue.uuidString)
        guard !json.isEmpty else { return nil }
        return try JSONDecoder().decode(ReadingPosition.self, from: Data(json.utf8))
    }

    private func writeLibrary(_ books: [Book]) throws {
        let json = String(decoding: try JSONEncoder().encode(books), as: UTF8.self)
        try callSaveLibrary(json: json)
    }

    // MARK: - Kotlin calls

    func callLoadLibrary() throws -> String {
        try JavaClass<BookBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "loadLibrary", resultType: String.self)
    }

    func callSaveLibrary(json: String) throws {
        try JavaClass<BookBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "saveLibrary", arguments: json)
    }

    func callLoadPosition(id: String) throws -> String {
        try JavaClass<BookBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "loadPosition", arguments: id, resultType: String.self)
    }

    func callSavePosition(id: String, json: String) throws {
        try JavaClass<BookBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "savePosition", arguments: id, json)
    }

    func callLoadCover(id: String) throws -> String {
        try JavaClass<BookBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "loadCover", arguments: id, resultType: String.self)
    }

    func callSaveCover(id: String, base64: String) throws {
        try JavaClass<BookBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "saveCover", arguments: id, base64)
    }

    func callClearBookData(id: String) throws {
        try JavaClass<BookBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "clearBookData", arguments: id)
    }

    func callDeleteFile(path: String) throws {
        try JavaClass<BookBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "deleteFile", arguments: path)
    }
}

// MARK: - File import (used by the Android import flow + probe)

public enum BookFileBridge {

    private static let logger = Logger(subsystem: "com.mn.core", category: "BookFileBridge")

    /// Copies a picked file into the app's books directory, returning the
    /// stored path. Empty string = failure.
    public static func importFile(srcPath: String, fileName: String) -> String {
        do {
            return try JavaClass<BookBlobStore>()
                .dynamicJavaStaticMethodCall(methodName: "importFile", arguments: srcPath, fileName, resultType: String.self)
        } catch {
            logger.warning("BookFileBridge.importFile failed: \(error)")
            return ""
        }
    }

    /// Reads a stored book file. The path lives on the same filesystem.
    public static func loadData(path: String) -> Data? {
        FileManager.default.contents(atPath: path)
    }

    /// Deletes a stored book file. Best effort.
    public static func deleteFile(path: String) {
        do {
            try JavaClass<BookBlobStore>()
                .dynamicJavaStaticMethodCall(methodName: "deleteFile", arguments: path)
        } catch {
            logger.warning("BookFileBridge.deleteFile failed: \(error)")
        }
    }
}

// MARK: - Android TextMeasurer

/// `TextMeasurer` backed by Kotlin's `TextMetrics` (Paint measurements,
/// cached Kotlin-side).
public struct KotlinTextMeasurer: TextMeasurer {

    public let fontSize: Double
    /// Ratio between the width Compose renders a string at and the width
    /// Paint measures for it (the two shape text slightly differently, 5–10%
    /// apart on some devices). The reader computes it on the Compose side and
    /// passes it in, so the engine wraps exactly as wide as the renderer can
    /// paint — otherwise the renderer re-wraps the engine's line and the page
    /// grows orphan words and double-height rows.
    public let widthScale: Double

    public init(fontSize: Double, widthScale: Double = 1.0) {
        self.fontSize = fontSize
        self.widthScale = widthScale
    }

    public func width(of text: String) -> Double {
        do {
            let measured = try JavaClass<KotlinTextMetrics>()
                .dynamicJavaStaticMethodCall(methodName: "measure", arguments: text, fontSize, resultType: Double.self)
            return measured * widthScale
        } catch {
            // Conservative fallback: slightly wide monospace estimate.
            KotlinBookStore.logMeasureFailure(error)
            return Double(text.count) * Double(fontSize) * 0.6
        }
    }

    public func lineHeight() -> Double {
        do {
            return try JavaClass<KotlinTextMetrics>()
                .dynamicJavaStaticMethodCall(methodName: "lineHeight", arguments: fontSize, resultType: Double.self)
        } catch {
            return fontSize * 1.45
        }
    }
}

extension KotlinBookStore {
    static func logMeasureFailure(_ error: Error) {
        Self.logger.warning("TextMetrics call failed: \(error)")
    }
}
