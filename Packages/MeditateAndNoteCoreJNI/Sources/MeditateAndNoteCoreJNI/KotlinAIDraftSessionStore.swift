//
//  KotlinAIDraftSessionStore.swift
//  MeditateAndNoteCoreJNI
//
//  The AI draft sessions, stored by Kotlin.
//
//  Division of labour, same as `KotlinNoteDataSource`: Swift owns the bytes
//  and the rules, Kotlin owns the storage. The session is a Codable
//  aggregate, so `JSONEncoder` runs here and Kotlin keeps one opaque string
//  per note that it never parses - there is no Kotlin mirror of the session
//  to drift when a field is added.
//
//  The protocol's methods are async, the JNI call is not: the async surface
//  does the work inline and returns, and the sync forms are what the bridge
//  (a `@_cdecl` entry point with no event loop to await on) drives.
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

/// The Kotlin object's JVM class. Bound to `AIDraftSessionStore`.
@JavaClass("com.mn.android.data.AIDraftSessionStorage")
public class AIDraftSessionStorage: JavaObject {}

/// SharedPreferences-backed storage for the AI draft sessions.
///
/// ponytail: this does NOT conform to Core's `AIDraftSessionStore` protocol.
/// The Swift 6.4 optimizer crashes (SIL `cgscc(devirt)`) on any new
/// conformance to that async protocol in this module - as a struct and as an
/// actor alike - so the bridge drives the synchronous forms below instead.
/// The contract itself is unchanged: one session per note, the document
/// written by Core, the storage owned by Kotlin. Revisit when the toolchain
/// is fixed.
public struct KotlinAIDraftSessionStore {

    public init() {}

    // MARK: - Synchronous core

    func fetchSync(noteID: NoteID) throws -> AIDraftSession? {
        let document = try Self.callLoad(noteId: noteID.rawValue.uuidString)
        guard !document.isEmpty else { return nil }
        guard let data = document.data(using: .utf8) else { return nil }
        return try JSONDecoder().decode(AIDraftSession.self, from: data)
    }

    func fetchAllSync() throws -> [AIDraftSession] {
        let json = try Self.callAll()
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        return object.values.compactMap { document in
            guard let text = document as? String,
                  let data = text.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(AIDraftSession.self, from: data)
        }
    }

    func saveSync(_ session: AIDraftSession) throws {
        let document = String(decoding: try JSONEncoder().encode(session), as: UTF8.self)
        try Self.callSave(noteId: session.noteID.rawValue.uuidString, document: document)
    }

    func deleteSync(noteID: NoteID) throws {
        try Self.callDelete(noteId: noteID.rawValue.uuidString)
    }

    // MARK: - Kotlin calls

    private static func callLoad(noteId: String) throws -> String {
        try JavaClass<AIDraftSessionStorage>()
            .dynamicJavaStaticMethodCall(methodName: "load", arguments: noteId, resultType: String.self)
    }

    private static func callAll() throws -> String {
        try JavaClass<AIDraftSessionStorage>()
            .dynamicJavaStaticMethodCall(methodName: "all", resultType: String.self)
    }

    private static func callSave(noteId: String, document: String) throws {
        try JavaClass<AIDraftSessionStorage>()
            .dynamicJavaStaticMethodCall(methodName: "save", arguments: noteId, document)
    }

    private static func callDelete(noteId: String) throws {
        try JavaClass<AIDraftSessionStorage>()
            .dynamicJavaStaticMethodCall(methodName: "delete", arguments: noteId)
    }
}
