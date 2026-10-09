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

// MARK: - Streak header (home screen)

/// Fills one flag per day for the 7 day-start millis Kotlin sent, and returns
/// the current streak.
///
/// Same out-param rule as the probes: Kotlin allocates the flag arrays, Swift
/// only fills them. `StreakSnapshot` is decoded here and on the Kotlin side
/// stays an opaque JSON document, so there is still no Kotlin mirror of the
/// snapshot shape to drift.
///
/// Kotlin side: StreakHeaderSource.kt
@_cdecl("Java_com_mn_android_data_StreakHeaderSource_read")
public func Java_com_mn_android_data_StreakHeaderSource_read(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    dayStartMillis: jlongArray,
    medFlags: jlongArray,
    noteFlags: jlongArray
) -> jlong {
    let days = [Int64](fromJNI: dayStartMillis, in: environment)
    let snapshot = KotlinStreakActivityStore().load()

    var med = [Int64](repeating: 0, count: days.count)
    var note = [Int64](repeating: 0, count: days.count)
    for (i, millis) in days.enumerated() {
        let day = Date(timeIntervalSince1970: Double(millis) / 1000.0)
        let activity = snapshot?.activities.first {
            Calendar.current.isDate($0.date, inSameDayAs: day)
        }
        med[i] = activity?.hasMeditation == true ? 1 : 0
        note[i] = activity?.hasNote == true ? 1 : 0
    }
    writeValues(med, to: medFlags, in: environment)
    writeValues(note, to: noteFlags, in: environment)
    return Int64(snapshot?.currentStreak ?? 0)
}

// MARK: - Streak header probe

/// Writes a known snapshot, then fills the header flags for the same 7 days
/// the Kotlin screen would ask for. Proves the newest JNI entry point on
/// device: symbol, signature, and that Swift and Kotlin agree on what
/// "yesterday" means.
///
/// Results: [0] currentStreak == 7, [1] yesterday meditation,
/// [2] yesterday note, [3] two-days-ago meditation, [4] two-days-ago note
/// cleared, [5] today clean, [6] 1 if a step threw.
///
/// Kotlin side: StreakHeaderProbe.kt
@_cdecl("Java_com_mn_android_NativeProbe_streakHeaderProbe")
public func Java_com_mn_android_NativeProbe_streakHeaderProbe(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    out: jlongArray
) {
    let store = KotlinStreakActivityStore()
    var results = [Int64](repeating: 0, count: 7)
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: today)!
    }

    do {
        try store.saveSync(StreakSnapshot(
            activities: [
                DailyActivity(
                    date: day(1),
                    hasMeditation: true,
                    hasNote: true,
                    meditationTime: day(1),
                    noteTime: day(1)
                ),
                DailyActivity(date: day(2), hasMeditation: true, hasNote: false),
                DailyActivity(date: day(3), hasMeditation: false, hasNote: true),
            ],
            currentStreak: 7,
            longestStreak: 7,
            lastCountedDay: day(1)
        ))

        // Same lookup the header thunk does, over the same last-7-days window.
        for offset in (0..<7) {
            let dayDate = day(6 - offset)
            let activity = store.load()?.activities.first {
                calendar.isDate($0.date, inSameDayAs: dayDate)
            }
            let med = activity?.hasMeditation == true ? 1 : 0
            let note = activity?.hasNote == true ? 1 : 0

            switch (6 - offset) {
            case 1: // yesterday
                results[1] = Int64(med)
                results[2] = Int64(note)
            case 2: // two days ago — meditation only
                results[3] = Int64(med)
                results[4] = Int64(note)
            case 6: // today — no activity stored
                results[5] = Int64(med | note)
            case _:
                break
            }
        }
        results[0] = Int64(store.load()?.currentStreak == 7 ? 1 : 0)
    } catch {
        KotlinStreakActivityStore.logProbeFailure(error)
        results[6] = 1
    }

    writeValues(results, to: out, in: environment)
}
