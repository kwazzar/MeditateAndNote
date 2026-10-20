//
//  KotlinNoteInsightStore.swift
//  MeditateAndNoteCoreJNI
//
//  A `NoteInsightStore` that persists through Kotlin's SharedPreferences.
//
//  The Android counterpart of `CoreDataNoteInsightStore`: the same Core
//  protocol, a different storage engine. Division of labour: Swift owns the
//  bytes — it encodes `NoteInsight` — Kotlin owns the table and never parses
//  an insight, it only hands the payloads back.
//
//  The async surface of `NoteInsightStore` is real for `CoreDataNoteInsightStore`
//  and not real here: JNI is a blocking call, so every method does its work
//  inline and returns. The sync forms exist so the bridge — a `@_cdecl` entry
//  point with no event loop to await on — can drive the store without hopping
//  threads.
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

/// The Kotlin object's JVM class. Bound to `NoteInsightBlobStore`.
@JavaClass("com.mn.android.data.NoteInsightBlobStore")
public class NoteInsightBlobStore: JavaObject {}

/// SharedPreferences-backed implementation of `NoteInsightStore`.
public struct KotlinNoteInsightStore: NoteInsightStore {

    private static let logger = Logger(subsystem: "com.mn.core", category: "NoteInsightStore")

    public init() {}

    public func fetchAll() async throws -> [NoteInsight] { try fetchAllSync() }
    public func fetch(noteID: NoteID) async throws -> NoteInsight? { try fetchSync(noteID: noteID) }
    public func save(_ insight: NoteInsight) async throws { try saveSync(insight) }
    public func delete(noteID: NoteID) async throws { try deleteSync(noteID: noteID) }
    public func deleteAll() async throws { try deleteAllSync() }

    // MARK: - Synchronous core

    func fetchAllSync() throws -> [NoteInsight] {
        do {
            let json = try Self.callFetchAll()
            guard let data = json.data(using: .utf8), !data.isEmpty else { return [] }
            return try JSONDecoder().decode([NoteInsight].self, from: data)
        } catch {
            Self.logger.warning("NoteInsightStore.fetchAll failed: \(error)")
            throw error
        }
    }

    func fetchSync(noteID: NoteID) throws -> NoteInsight? {
        do {
            // Kotlin returns "" for "nothing stored", because Optional<String>
            // cannot cross as String?.self. An insight payload always encodes
            // a JSON object, so an empty string never collides with a real row.
            let payload = try Self.callLoad(id: noteID.rawValue.uuidString)
            guard !payload.isEmpty else { return nil }
            return try JSONDecoder().decode(NoteInsight.self, from: Data(payload.utf8))
        } catch {
            Self.logger.warning("NoteInsightStore.fetch failed: \(error)")
            throw error
        }
    }

    func saveSync(_ insight: NoteInsight) throws {
        do {
            let payload = String(decoding: try JSONEncoder().encode(insight), as: UTF8.self)
            try Self.callSave(id: insight.noteID.rawValue.uuidString, payload: payload)
        } catch {
            Self.logger.warning("NoteInsightStore.save failed: \(error)")
            throw error
        }
    }

    func deleteSync(noteID: NoteID) throws {
        do {
            try Self.callDelete(id: noteID.rawValue.uuidString)
        } catch {
            Self.logger.warning("NoteInsightStore.delete failed: \(error)")
            throw error
        }
    }

    func deleteAllSync() throws {
        do {
            try Self.callDeleteAll()
        } catch {
            Self.logger.warning("NoteInsightStore.deleteAll failed: \(error)")
            throw error
        }
    }

    // MARK: - Kotlin calls

    private static func callFetchAll() throws -> String {
        try JavaClass<NoteInsightBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "fetchAll", resultType: String.self)
    }

    private static func callLoad(id: String) throws -> String {
        try JavaClass<NoteInsightBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "load", arguments: id, resultType: String.self)
    }

    private static func callSave(id: String, payload: String) throws {
        // No resultType: Kotlin returns void, and Void does not conform to
        // JavaValue.
        try JavaClass<NoteInsightBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "save", arguments: id, payload)
    }

    private static func callDelete(id: String) throws {
        try JavaClass<NoteInsightBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "delete", arguments: id)
    }

    private static func callDeleteAll() throws {
        try JavaClass<NoteInsightBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "deleteAll")
    }
}
