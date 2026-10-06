//
//  KotlinNoteDataSource.swift
//  MeditateAndNoteCoreJNI
//
//  A `NoteDataSource` that persists through Kotlin's SQLite.
//
//  Option D from ANDROID_PORT_PLAN: a blob row, not Room. The store's query
//  surface is "all notes by date", "one by id", save, delete — and search runs
//  in memory over [Note] on both platforms — so Room would be bought for query
//  power nothing asks for, and would add a third declaration of Note's fields
//  alongside the Swift struct and CoreDataManager.buildModel().
//
//  Division of labour: Swift owns the bytes, Kotlin owns the table.
//  `JSONEncoder` runs in Swift, Kotlin stores `payload` as opaque text and never
//  parses it, and the only column it interprets is the sort key. That is why
//  there is no Kotlin-side mirror of Note to drift.
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

/// The Kotlin object's JVM class. Bound to `NoteBlobStore`.
@JavaClass("com.mn.android.data.NoteBlobStore")
public class NoteBlobStore: JavaObject {}

/// SQLite-backed implementation of `NoteDataSource`.
///
/// The async surface of `NoteDataSource` is real for `CoreDataNoteDataSource`
/// and not real here: JNI is a blocking call, so every method does its work
/// inline and returns. The sync forms exist so the probe — a `@_cdecl` entry
/// point with no event loop to await on — can drive the store without hopping
/// threads and racing the out-param.
public struct KotlinNoteDataSource: NoteDataSource {

    private static let logger = Logger(subsystem: "com.mn.core", category: "NoteDataSource")

    public init() {}

    public func fetchAll() async throws -> [Note] { try fetchAllSync() }
    public func fetch(id: NoteID) async throws -> Note? { try fetchSync(id: id) }
    public func save(_ note: Note) async throws { try saveSync(note) }
    public func delete(id: NoteID) async throws { try deleteSync(id: id) }
    public func deleteAll() async throws { try deleteAllSync() }

    // MARK: - Synchronous core

    func fetchAllSync() throws -> [Note] {
        do {
            let json = try Self.callFetchAll()
            return try JSONDecoder().decode([Note].self, from: Data(json.utf8))
        } catch {
            Self.logger.warning("NoteDataSource.fetchAll failed: \(error)")
            throw NoteOperationError.loadAllFailed
        }
    }

    func fetchSync(id: NoteID) throws -> Note? {
        do {
            // Kotlin returns "" for "nothing stored", because Optional<String>
            // cannot cross as String?.self. A note payload always encodes a JSON
            // object, so an empty string never collides with a real row.
            let payload = try Self.callLoad(id: id.rawValue.uuidString)
            guard !payload.isEmpty else { return nil }
            return try JSONDecoder().decode(Note.self, from: Data(payload.utf8))
        } catch {
            Self.logger.warning("NoteDataSource.fetch failed: \(error)")
            throw NoteOperationError.loadFailed(id)
        }
    }

    func saveSync(_ note: Note) throws {
        do {
            let payload = String(decoding: try JSONEncoder().encode(note), as: UTF8.self)
            try Self.callSave(
                id: note.id.rawValue.uuidString,
                date: Int64(note.date.timeIntervalSince1970 * 1000),
                payload: payload
            )
        } catch {
            Self.logger.warning("NoteDataSource.save failed: \(error)")
            throw NoteOperationError.saveFailed
        }
    }

    func deleteSync(id: NoteID) throws {
        do {
            try Self.callDelete(id: id.rawValue.uuidString)
        } catch {
            Self.logger.warning("NoteDataSource.delete failed: \(error)")
            throw NoteOperationError.deleteFailed(id)
        }
    }

    func deleteAllSync() throws {
        do {
            try Self.callDeleteAll()
        } catch {
            Self.logger.warning("NoteDataSource.deleteAll failed: \(error)")
            throw NoteOperationError.deleteAllFailed
        }
    }

    // MARK: - Kotlin calls

    // `JavaClass()` throwing rather than `try!` on purpose: a missing class
    // should surface as a domain error the caller can handle, not as a bare
    // SIGTRAP with no stack, which is what `try!` produced for the reminder store
    // when its Kotlin package disagreed with @JavaClass.

    private static func callFetchAll() throws -> String {
        try JavaClass<NoteBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "fetchAll", resultType: String.self)
    }

    private static func callLoad(id: String) throws -> String {
        try JavaClass<NoteBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "load", arguments: id, resultType: String.self)
    }

    private static func callSave(id: String, date: Int64, payload: String) throws {
        // No resultType: Kotlin returns void, and Void does not conform to
        // JavaValue.
        try JavaClass<NoteBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "save", arguments: id, date, payload)
    }

    private static func callDelete(id: String) throws {
        try JavaClass<NoteBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "delete", arguments: id)
    }

    private static func callDeleteAll() throws {
        try JavaClass<NoteBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "deleteAll")
    }
}

// MARK: - Kotlin entry points

/// Slots in the probe buffer, in order.
///
/// Kotlin allocates `LongArray(NOTE_PROBE_SLOTS)` and this file fills it in
/// place — Kotlin cannot observe Swift replacing an out-param, so the buffer has
/// to belong to Kotlin.
private let noteProbeSlots = 8

/// Drives the whole blob round trip from Kotlin through Swift and back, and
/// reports what it found as counts and flags rather than a formatted string:
/// structured values do not cross JNI, and print from Swift never reaches
/// logcat on this device.
///
/// Results: [0] rows after saving 2, [1] fetchAll returned 2, [2] newest-first
/// order holds, [3] note loaded intact, [4] rows after deleting one, [5] rows
/// after deleteAll, [6] 1 if a step threw, [7] unused.
///
/// Kotlin side: NoteProbe.kt
@_cdecl("Java_com_mn_android_NativeProbe_noteProbe")
public func Java_com_mn_android_NativeProbe_noteProbe(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    out: jlongArray
) {
    let store = KotlinNoteDataSource()
    var results = [Int64](repeating: 0, count: noteProbeSlots)

    // A failed step is recorded in slot 6 rather than aborting, so the probe
    // still reports how far it got.
    do {
        // Clean slate: the probe must not depend on what the last run left.
        try? store.deleteAllSync()

        let newer = Note(
            title: NoteTitle("newer"),
            content: NoteContent("alpha"),
            date: Date()
        )
        let older = Note(
            title: NoteTitle("older"),
            content: NoteContent("beta"),
            date: Date().addingTimeInterval(-86_400)
        )

        try store.saveSync(newer)
        try store.saveSync(older)

        let all = try store.fetchAllSync()
        results[0] = Int64(all.count)
        results[1] = all.count == 2 ? 1 : 0
        results[2] = all.first?.id == newer.id ? 1 : 0
        results[3] = try store.fetchSync(id: newer.id)?.title.rawValue == "newer" ? 1 : 0

        try store.deleteSync(id: older.id)
        results[4] = Int64(try store.fetchAllSync().count)

        try store.deleteAllSync()
        results[5] = Int64(try store.fetchAllSync().count)
    } catch {
        KotlinNoteDataSource.logProbeFailure(error)
        results[6] = 1
    }

    writeValues(results, to: out, in: environment)
}

extension KotlinNoteDataSource {
    static func logProbeFailure(_ error: Error) {
        Self.logger.warning("note probe failed: \(error)")
    }
}
