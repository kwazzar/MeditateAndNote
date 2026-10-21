//
//  KotlinBookmarkStore.swift
//  MeditateAndNoteCoreJNI
//
//  A `BookmarkStore` that persists through Kotlin's SharedPreferences.
//
//  Same division of labour as `KotlinStreakActivityStore`: Swift owns the
//  bytes (one JSON array of marks), Kotlin owns the storage. Kotlin never
//  parses the document, so the Core shape exists in exactly one place.
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

/// The Kotlin object's JVM class. Bound to `BookmarkBlobStore`.
@JavaClass("com.mn.android.data.BookmarkBlobStore")
public class BookmarkBlobStore: JavaObject {}

/// SharedPreferences-backed implementation of `BookmarkStore`.
public struct KotlinBookmarkStore: BookmarkStore {

    private static let logger = Logger(subsystem: "com.mn.core", category: "BookmarkStore")

    public init() {}

    public func fetchAll(bookID: BookID) async throws -> [Bookmark] {
        try allSync().filter { $0.bookID == bookID }
    }

    public func fetch(id: BookmarkID) async throws -> Bookmark? {
        try allSync().first { $0.id == id }
    }

    public func save(_ bookmark: Bookmark) async throws {
        var marks = try allSync()
        if let index = marks.firstIndex(where: { $0.id == bookmark.id }) {
            marks[index] = bookmark
        } else {
            marks.append(bookmark)
        }
        try write(marks)
    }

    public func delete(id: BookmarkID) async throws {
        let marks = try allSync().filter { $0.id != id }
        try write(marks)
    }

    public func deleteAll(bookID: BookID) async throws {
        let marks = try allSync().filter { $0.bookID != bookID }
        try write(marks)
    }

    // MARK: - Synchronous core

    func allSync() throws -> [Bookmark] {
        let json = try Self.callLoad()
        guard !json.isEmpty else { return [] }
        return try JSONDecoder().decode([Bookmark].self, from: Data(json.utf8))
    }

    /// Synchronous upsert, used by the reader thunks.
    func saveSync(_ bookmark: Bookmark) throws {
        var marks = try allSync()
        if let index = marks.firstIndex(where: { $0.id == bookmark.id }) {
            marks[index] = bookmark
        } else {
            marks.append(bookmark)
        }
        try write(marks)
    }

    /// Synchronous delete by id.
    func deleteSync(_ id: BookmarkID) throws {
        try write(try allSync().filter { $0.id != id })
    }

    func write(_ marks: [Bookmark]) throws {
        let json = String(decoding: try JSONEncoder().encode(marks), as: UTF8.self)
        try Self.callSave(json: json)
    }

    // MARK: - Kotlin calls

    private static func callLoad() throws -> String {
        try JavaClass<BookmarkBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "load", resultType: String.self)
    }

    private static func callSave(json: String) throws {
        try JavaClass<BookmarkBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "save", arguments: json)
    }
}
