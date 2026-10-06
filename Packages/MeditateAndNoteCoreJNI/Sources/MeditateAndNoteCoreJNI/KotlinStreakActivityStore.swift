//
//  KotlinStreakActivityStore.swift
//  MeditateAndNoteCoreJNI
//
//  A `StreakActivityStore` that persists through Kotlin's SharedPreferences.
//
//  Division of labour, same as `KotlinNoteDataSource`: Swift owns the bytes,
//  Kotlin owns the storage. `StreakSnapshot` is Codable in the domain package,
//  so `JSONEncoder` runs here and Kotlin keeps one opaque string it never
//  parses — there is no Kotlin mirror of the snapshot to drift when a field is
//  added. SharedPreferences rather than Room because this is a single row read
//  whole, never queried.
//
//  `load()` and `save(_:)` are non-throwing in the protocol, so the public
//  surface swallows and logs. The throwing forms exist for the probe, which has
//  to tell "stored document was invalid" apart from "the call never reached
//  Kotlin" — both look like `nil` otherwise.
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

/// The Kotlin object's JVM class. Bound to `StreakSnapshotStore`.
@JavaClass("com.mn.android.data.StreakSnapshotStore")
public class StreakSnapshotStore: JavaObject {}

/// SharedPreferences-backed implementation of `StreakActivityStore`.
public struct KotlinStreakActivityStore: StreakActivityStore {

    private static let logger = Logger(subsystem: "com.mn.core", category: "StreakStore")

    public init() {}

    public func load() -> StreakSnapshot? {
        do { return try loadSync() } catch {
            Self.logger.warning("StreakActivityStore.load failed: \(error)")
            return nil
        }
    }

    public func save(_ snapshot: StreakSnapshot) async {
        do { try saveSync(snapshot) } catch {
            Self.logger.warning("StreakActivityStore.save failed: \(error)")
        }
    }

    // MARK: - Synchronous core

    func loadSync() throws -> StreakSnapshot? {
        // "" means nothing stored: `String?` does not cross JNI, and a snapshot
        // always encodes as a non-empty JSON object, so the sentinel never
        // collides with a real value.
        let json = try Self.callLoad()
        guard !json.isEmpty else { return nil }
        do {
            return try JSONDecoder().decode(StreakSnapshot.self, from: Data(json.utf8))
        } catch {
            // Never return a partially populated snapshot — the protocol's one
            // hard promise. A corrupt document reads as "no streak yet".
            Self.logger.warning("StreakActivityStore: stored snapshot is invalid, returning nil: \(error)")
            return nil
        }
    }

    func saveSync(_ snapshot: StreakSnapshot) throws {
        let json = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
        try Self.callSave(json: json)
    }

    /// Writes a document this type cannot decode, so the probe can prove the
    /// corrupt path returns nil instead of a half-built snapshot.
    func corruptStorage() throws {
        try Self.callSave(json: "{")
    }

    // MARK: - Kotlin calls

    // `JavaClass()` throwing rather than `try!` on purpose, as in
    // KotlinNoteDataSource: a missing class must surface as a handleable error,
    // not a bare SIGTRAP with no stack.

    private static func callLoad() throws -> String {
        try JavaClass<StreakSnapshotStore>()
            .dynamicJavaStaticMethodCall(methodName: "load", resultType: String.self)
    }

    private static func callSave(json: String) throws {
        // No resultType: Kotlin returns void, and Void does not conform to
        // JavaValue.
        try JavaClass<StreakSnapshotStore>()
            .dynamicJavaStaticMethodCall(methodName: "save", arguments: json)
    }
}

// MARK: - Kotlin entry point

/// Slots in the probe buffer, in order.
///
/// Kotlin allocates `LongArray(STREAK_PROBE_SLOTS)` and this file fills it in
/// place — Kotlin cannot observe Swift replacing an out-param, so the buffer has
/// to belong to Kotlin.
private let streakProbeSlots = 8

/// Drives the whole round trip from Kotlin through Swift and back: encode ->
/// SharedPreferences -> decode, then a second save to prove replacement, then a
/// deliberately invalid document to prove the corrupt path.
///
/// Results: [0] snapshot loaded, [1] currentStreak survived, [2] activities
/// count survived, [3] lastCountedDay survived, [4] day flags survived,
/// [5] second save replaced the first, [6] invalid document read as nil,
/// [7] 1 if a step threw.
///
/// Kotlin side: StreakProbe.kt
@_cdecl("Java_com_mn_android_NativeProbe_streakProbe")
public func Java_com_mn_android_NativeProbe_streakProbe(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    out: jlongArray
) {
    let store = KotlinStreakActivityStore()
    var results = [Int64](repeating: 0, count: streakProbeSlots)

    do {
        // Clean slate: the probe must not depend on what the last run left.
        // `save` replaces the single stored document, so no delete is needed —
        // the protocol has no delete operation.
        let countedDay = Date().addingTimeInterval(-86_400)
        let first = StreakSnapshot(
            activities: [
                DailyActivity(
                    date: countedDay,
                    hasMeditation: true,
                    hasNote: true,
                    meditationTime: countedDay,
                    noteTime: countedDay
                ),
                DailyActivity(
                    date: countedDay.addingTimeInterval(-86_400),
                    hasMeditation: true,
                    hasNote: false
                ),
                DailyActivity(
                    date: countedDay.addingTimeInterval(-172_800),
                    hasMeditation: false,
                    hasNote: true
                ),
            ],
            currentStreak: 4,
            longestStreak: 9,
            lastCountedDay: countedDay
        )

        try store.saveSync(first)
        if let loaded = try store.loadSync() {
            results[0] = 1
            results[1] = loaded.currentStreak == 4 ? 1 : 0
            results[2] = loaded.activities.count == 3 ? 1 : 0
            // Date crosses as a Double; compare with a tolerance rather than
            // trusting the encoder to round-trip it bit for bit.
            if let day = loaded.lastCountedDay, let expected = first.lastCountedDay {
                results[3] = abs(day.timeIntervalSince(expected)) < 0.001 ? 1 : 0
            }
            if let day = loaded.activities.first {
                results[4] = (day.hasMeditation && day.hasNote && day.meditationTime != nil) ? 1 : 0
            }
        }

        let second = StreakSnapshot(
            activities: [],
            currentStreak: 7,
            longestStreak: 9
        )
        try store.saveSync(second)
        results[5] = try store.loadSync()?.currentStreak == 7 ? 1 : 0

        // Corrupt path last: it destroys the stored document, and the next run
        // starts by overwriting it anyway.
        try store.corruptStorage()
        results[6] = try store.loadSync() == nil ? 1 : 0
    } catch {
        KotlinStreakActivityStore.logProbeFailure(error)
        results[7] = 1
    }

    writeValues(results, to: out, in: environment)
}

extension KotlinStreakActivityStore {
    static func logProbeFailure(_ error: Error) {
        Self.logger.warning("streak probe failed: \(error)")
    }
}
