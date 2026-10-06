//
//  KotlinMeditationSessionStore.swift
//  MeditateAndNoteCoreJNI
//
//  A `MeditationSessionStore` that persists through Kotlin's SQLite.
//
//  Same division of labour as `KotlinNoteDataSource`: Swift owns the bytes,
//  Kotlin owns the table. The payload is written by `JSONEncoder` here and
//  never parsed on the Kotlin side, so `MeditationSession` gaining a field does
//  not touch Kotlin.
//
//  The one thing Kotlin interprets is `completedAt`, because the day-window
//  query has to run in SQL. That is safe: `completedAt` is a `let`, so the
//  column cannot drift from the payload it is derived from. The half-open
//  `[start, end)` window is computed with Swift's `Calendar.current`, matching
//  `CoreDataSessionStore` predicate for predicate — the two implementations
//  agree on a day only as long as they share a time zone, which is noted on the
//  protocol rather than papered over here.
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

/// The Kotlin object's JVM class. Bound to `SessionBlobStore`.
@JavaClass("com.mn.android.data.SessionBlobStore")
public class SessionBlobStore: JavaObject {}

/// SQLite-backed implementation of `MeditationSessionStore`.
///
/// The protocol methods are non-throwing, so the public surface logs and
/// degrades to an empty result. The throwing forms exist for the probe, which
/// has to tell "nothing stored" apart from "the call never reached Kotlin".
public struct KotlinMeditationSessionStore: MeditationSessionStore {

    private static let logger = Logger(subsystem: "com.mn.core", category: "SessionStore")

    public init() {}

    public func save(_ session: MeditationSession) async {
        do { try saveSync(session) } catch {
            Self.logger.warning("MeditationSessionStore.save failed: \(error)")
        }
    }

    public func sessions(for date: Date) async -> [MeditationSession] {
        do { return try sessionsSync(for: date) } catch {
            Self.logger.warning("MeditationSessionStore.sessions failed: \(error)")
            return []
        }
    }

    public func allSessionDates() async -> Set<Date> {
        do { return try allSessionDatesSync() } catch {
            Self.logger.warning("MeditationSessionStore.allSessionDates failed: \(error)")
            return []
        }
    }

    // MARK: - Synchronous core

    func saveSync(_ session: MeditationSession) throws {
        let payload = String(decoding: try JSONEncoder().encode(session), as: UTF8.self)
        try Self.callSave(
            id: session.id.rawValue.uuidString,
            completedAt: Int64(session.completedAt.timeIntervalSince1970 * 1000),
            payload: payload
        )
    }

    func sessionsSync(for date: Date) throws -> [MeditationSession] {
        // Same window as `CoreDataSessionStore`: `completedAt >= start AND
        // completedAt < end`, upper bound excluded so midnight belongs to the
        // following day only.
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return try Self.callFetch(
            start: Int64(start.timeIntervalSince1970 * 1000),
            end: Int64(end.timeIntervalSince1970 * 1000)
        )
    }

    /// Same derivation the protocol method does, exposed synchronously because
    /// the `@_cdecl` probe entry point has no event loop to await on — the
    /// async-over-sync-core split that `KotlinNoteDataSource` also uses.
    func allSessionDatesSync() throws -> Set<Date> {
        let calendar = Calendar.current
        return Set(try allSessionsSync().map { calendar.startOfDay(for: $0.completedAt) })
    }

    func allSessionsSync() throws -> [MeditationSession] {
        // Widening the same range query to the whole integer domain is what
        // `allSessionDates` needs, so there is no second query method.
        try Self.callFetch(start: .min, end: .max)
    }

    func deleteAllSync() throws {
        try Self.callDeleteAll()
    }

    // MARK: - Kotlin calls

    // `JavaClass()` throwing rather than `try!` on purpose, as in
    // KotlinNoteDataSource: a missing class must surface as a handleable error,
    // not a bare SIGTRAP with no stack.

    private static func callSave(id: String, completedAt: Int64, payload: String) throws {
        // No resultType: Kotlin returns void, and Void does not conform to
        // JavaValue.
        try JavaClass<SessionBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "save", arguments: id, completedAt, payload)
    }

    private static func callFetch(start: Int64, end: Int64) throws -> [MeditationSession] {
        let json = try JavaClass<SessionBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "fetch", arguments: start, end, resultType: String.self)
        return try JSONDecoder().decode([MeditationSession].self, from: Data(json.utf8))
    }

    private static func callDeleteAll() throws {
        try JavaClass<SessionBlobStore>()
            .dynamicJavaStaticMethodCall(methodName: "deleteAll")
    }
}

// MARK: - Kotlin entry point

/// Slots in the probe buffer, in order.
///
/// Kotlin allocates `LongArray(SESSION_PROBE_SLOTS)` and this file fills it in
/// place — Kotlin cannot observe Swift replacing an out-param, so the buffer has
/// to belong to Kotlin.
private let sessionProbeSlots = 8

/// Drives the whole round trip from Kotlin through Swift and back: encode ->
/// SQLite -> decode, split by day, ordered, then a range on an unrelated day,
/// then deletion.
///
/// Results: [0] sessions on day one, [1] sessions on day two, [2] sessions on an
/// unrelated day, [3] distinct session days, [4] newest first, [5] duration
/// survived, [6] sessions after deleteAll, [7] 1 if a step threw.
///
/// Kotlin side: SessionProbe.kt
@_cdecl("Java_com_mn_android_NativeProbe_sessionProbe")
public func Java_com_mn_android_NativeProbe_sessionProbe(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    out: jlongArray
) {
    let store = KotlinMeditationSessionStore()
    var results = [Int64](repeating: 0, count: sessionProbeSlots)

    do {
        // Clean slate: the probe must not depend on what the last run left.
        try store.deleteAllSync()

        let calendar = Calendar.current
        let dayOne = calendar.startOfDay(for: Date())
        guard
            let dayTwo = calendar.date(byAdding: .day, value: -1, to: dayOne),
            let unrelatedDay = calendar.date(byAdding: .day, value: -5, to: dayOne)
        else {
            results[7] = 1
            writeValues(results, to: out, in: environment)
            return
        }

        let early = MeditationSession(
            meditationId: MeditationID(rawValue: "m1"),
            completedAt: dayOne.addingTimeInterval(1_800),
            duration: SessionDuration(seconds: 60)
        )
        let late = MeditationSession(
            meditationId: MeditationID(rawValue: "m1"),
            completedAt: dayOne.addingTimeInterval(7_200),
            duration: SessionDuration(seconds: 120)
        )
        let previous = MeditationSession(
            meditationId: MeditationID(rawValue: "m2"),
            completedAt: dayTwo.addingTimeInterval(600),
            duration: SessionDuration(seconds: 60)
        )

        try store.saveSync(early)
        try store.saveSync(late)
        try store.saveSync(previous)

        let dayOneSessions = try store.sessionsSync(for: dayOne)
        results[0] = dayOneSessions.count == 2 ? 1 : 0
        results[1] = try store.sessionsSync(for: dayTwo).count == 1 ? 1 : 0
        results[2] = try store.sessionsSync(for: unrelatedDay).isEmpty ? 1 : 0
        results[3] = try store.allSessionDatesSync().count == 2 ? 1 : 0

        // `late` completed after `early`, so descending order puts it first.
        results[4] = dayOneSessions.first?.id == late.id ? 1 : 0
        results[5] = try store.sessionsSync(for: dayTwo).first?.duration.seconds == 60 ? 1 : 0

        try store.deleteAllSync()
        results[6] = try store.sessionsSync(for: dayOne).isEmpty ? 1 : 0
    } catch {
        KotlinMeditationSessionStore.logProbeFailure(error)
        results[7] = 1
    }

    writeValues(results, to: out, in: environment)
}

extension KotlinMeditationSessionStore {
    static func logProbeFailure(_ error: Error) {
        Self.logger.warning("session probe failed: \(error)")
    }
}
