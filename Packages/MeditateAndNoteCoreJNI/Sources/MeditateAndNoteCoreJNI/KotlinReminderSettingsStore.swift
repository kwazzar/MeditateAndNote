//
//  KotlinReminderSettingsStore.swift
//  MeditateAndNoteCoreJNI
//
//  A `ReminderSettingsStore` that persists through Kotlin's SharedPreferences.
//
//  This is Phase 2's proof that a Swift protocol can be implemented on the
//  Android side: the domain declares the contract, Swift code depends only on
//  the protocol, and Kotlin supplies the storage. The reverse JNI direction was
//  verified separately in ReverseJniProbe.swift.
//
//  The wire format is flat on purpose. Kotlin returns [enabled, hour, minute,
//  ...weekdays] as one LongArray and takes primitives back, rather than
//  exchanging `ReminderSettings` directly. Handing a Swift struct across the
//  boundary would need an arena on the Kotlin side and would put the
//  hour/minute clamping in two places; here the invariant stays in
//  `ReminderSettings.init`, and Kotlin's job ends at storing four values.
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

/// The Kotlin object's JVM class. Bound to `SharedPrefsReminderSettingsStore`.
@JavaClass("com.mn.android.data.SharedPrefsReminderSettingsStore")
public class SharedPrefsReminderSettingsStore: JavaObject {}

/// Persists `ReminderSettings` in Kotlin's SharedPreferences.
public struct KotlinReminderSettingsStore: ReminderSettingsStore {

    static let logger = Logger(
        subsystem: "com.mn.core",
        category: "ReminderSettingsStore"
    )

    public init() {}

    public func load() -> ReminderSettings {
        let flat = Self.callLoad() ?? [0, 20, 0]
        // Fewer than three values means Kotlin is not what we think it is;
        // defaultValue is the documented fallback for "nothing stored".
        guard flat.count >= 3 else { return .defaultValue }

        let weekdays = Set(flat.dropFirst(3).map(Int.init))
        // Empty would mean Kotlin stored an empty set, which ReminderSettings
        // forbids. Leaving it empty lets the initializer apply its own
        // fallback instead of us inventing one here.
        return ReminderSettings(
            isEnabled: flat[0] != 0,
            hour: Int(flat[1]),
            minute: Int(flat[2]),
            weekdays: weekdays
        )
    }

    public func save(_ settings: ReminderSettings) {
        var flat: [Int64] = [
            settings.isEnabled ? 1 : 0,
            Int64(settings.hour),
            Int64(settings.minute),
        ]
        // Sorted so a save/load round trip compares equal rather than depending
        // on Set's iteration order.
        flat.append(contentsOf: settings.sortedWeekdays.map(Int64.init))
        Self.callSave(enabled: settings.isEnabled, hour: Int32(settings.hour),
                      minute: Int32(settings.minute), weekdays: flat.dropFirst(3))
    }

    private static func callLoad() -> [Int64]? {
        let store: JavaClass<SharedPrefsReminderSettingsStore> = try! JavaClass()
        do {
            return try store.dynamicJavaStaticMethodCall(
                methodName: "load",
                resultType: [Int64].self
            )
        } catch {
            Self.logger.warning("ReminderSettingsStore.load failed: \(error)")
            return nil
        }
    }

    private static func callSave(enabled: Bool, hour: Int32, minute: Int32, weekdays: ArraySlice<Int64>) {
        let store: JavaClass<SharedPrefsReminderSettingsStore> = try! JavaClass()
        do {
            // No resultType: Kotlin's save returns void, and the void overload
            // exists because Void itself does not conform to JavaValue.
            try store.dynamicJavaStaticMethodCall(
                methodName: "save",
                arguments: enabled,
                hour,
                minute,
                Array(weekdays)
            )
        } catch {
            Self.logger.warning("ReminderSettingsStore.save failed: \(error)")
        }
    }
}

// MARK: - Kotlin entry points

/// Saves through Kotlin, then reads back and writes the result into `out`.
///
/// `out` receives [enabled, hour, minute, weekdayCount, ...weekdays].
///
/// Kotlin side: ReminderSettingsProbe.kt
@_cdecl("Java_com_mn_android_NativeProbe_saveReminders")
public func Java_com_mn_android_NativeProbe_saveReminders(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    enabled: jboolean,
    hour: jint,
    minute: jint,
    weekdays: jlongArray,
    out: jlongArray
) {
    // Array<Int64> already knows how to read a jlongArray through
    // SwiftJavaJNICore's JavaValue conformance, so no manual JNI here.
    let weekdayValues = [Int64](fromJNI: weekdays, in: environment).map(Int.init)

    let store = KotlinReminderSettingsStore()
    // The clamping happens here, in ReminderSettings.init, not in Kotlin: hour
    // 99 has to come back as 23.
    store.save(ReminderSettings(
        isEnabled: enabled != 0,
        hour: Int(hour),
        minute: Int(minute),
        weekdays: Set(weekdayValues)
    ))
    writeValues(flatten(store.load()), to: out, in: environment)
}

/// Reads through Kotlin and writes [enabled, hour, minute, weekdayCount,
/// ...weekdays] into `out`.
///
/// Kotlin side: ReminderSettingsProbe.kt
@_cdecl("Java_com_mn_android_NativeProbe_loadReminders")
public func Java_com_mn_android_NativeProbe_loadReminders(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    out: jlongArray
) {
    writeValues(flatten(KotlinReminderSettingsStore().load()), to: out, in: environment)
}

/// Flattens settings to the wire shape Kotlin expects:
/// [enabled, hour, minute, weekdayCount, ...weekdays].
///
/// Sorted weekdays so a save/load round trip compares equal rather than
/// depending on Set's iteration order.
private func flatten(_ settings: ReminderSettings) -> [Int64] {
    [
        settings.isEnabled ? 1 : 0,
        Int64(settings.hour),
        Int64(settings.minute),
        Int64(settings.weekdays.count),
    ] + settings.sortedWeekdays.map(Int64.init)
}
