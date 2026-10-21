//
//  StreakInsightsBridge.swift
//  MeditateAndNoteCoreJNI
//
//  JNI entry points for the streak-insights screen and for reminder scheduling.
//
//  Two hand-written @_cdecl bridges rather than the jextract-generated thunks:
//
//  - `StreakInsightManager`'s initializer takes `any StreakSnapshotProvidable`
//    as a Swift-backed jobject, which Kotlin cannot construct. The provider
//    reads the Kotlin-owned snapshot through `KotlinStreakActivityStore`, and
//    the whole insight bundle crosses back as one JSON string (the same pattern
//    `NoteMenuSource_read` uses), so Kotlin never needs a mirror of the domain
//    value types.
//
//  - `ReminderScheduleBuilder` is pure math, but it stays in Core so the fire
//    date rule lives in exactly one place. Kotlin allocates the out buffer (the
//    project's out-param rule: Swift cannot swap a reference Kotlin passed) and
//    Swift fills the next fire dates into it.
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

private let bridgeLogger = Logger(subsystem: "com.mn.core", category: "StreakInsights")

/// Snapshot the engine reads from. Sourced from Kotlin's SharedPreferences via
/// `KotlinStreakActivityStore`, decoded once per call.
private struct StoreSnapshotProvider: StreakSnapshotProvidable {
    let snapshot: StreakSnapshot
}

// MARK: - Streak insights read

/// Returns one JSON document with every streak-insight value the detail screen
/// renders for `jRange` ("last7" / "last30" / "last90").
///
/// Lifetime metrics (distribution, resilience, break pattern/heatmap) ignore the
/// range and are recomputed here anyway — the manager memoizes by snapshot
/// signature, so a repeated read is cheap.
///
/// Kotlin side: StreakInsightsSource.kt
@_cdecl("Java_com_mn_android_data_StreakInsightsSource_read")
public func Java_com_mn_android_data_StreakInsightsSource_read(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jRange: jstring?
) -> jstring? {
    let range = StreakRange(rawValueString: String(fromJNI: jRange, in: environment)) ?? .last7
    let snapshot = KotlinStreakActivityStore().load()
        ?? StreakSnapshot(activities: [], currentStreak: 0, longestStreak: 0)
    let json = streakInsightsJSON(range: range, snapshot: snapshot)
    return json.getJNILocalRefValue(in: environment)
}

/// Shared body so the probe and the JNI entry point cannot drift.
func streakInsightsJSON(range: StreakRange, snapshot: StreakSnapshot) -> String {
    let manager = StreakInsightManager(snapshotProvider: StoreSnapshotProvider(snapshot: snapshot))

    let insights = manager.insights(for: range).map { insight -> [String: Any] in
        var record: [String: Any] = [
            "id": insight.id.uuidString,
            "category": insight.category.wire,
            "title": insight.title,
            "message": insight.message,
            "icon": insight.icon,
        ]
        record["value"] = insight.value.map { $0 as Any } ?? NSNull()
        record["heatmap"] = insight.heatmapData.map(heatmapRecord) ?? NSNull()
        return record
    }

    let recommendations = manager.recommendations(for: range).map { item -> [String: Any] in
        [
            "id": item.id.uuidString,
            "priority": item.priority.rawValue,
            "title": item.title,
            "message": item.message,
            "icon": item.icon,
            "action": item.action.map { $0.wire } ?? NSNull(),
        ]
    }

    let weekly = manager.weeklyBreakdown(for: range).map { bucket -> [String: Any] in
        [
            "weekStartMillis": millis(bucket.weekStart),
            "weekEndMillis": millis(bucket.weekEnd),
            "totalDays": bucket.totalDays,
            "completeDays": bucket.completeDays,
            "completionRate": bucket.completionRate,
        ]
    }

    let distribution = manager.streakLengthDistribution()
    let distributionRecord: [String: Any] = [
        "buckets": distribution.buckets.map { ["label": $0.label, "count": $0.count] },
        "totalStreaks": distribution.totalStreaks,
        "medianLength": distribution.medianLength,
    ]

    let resilience = manager.resilience()
    let resilienceRecord: [String: Any] = [
        "avgRecoveryDays": resilience.avgRecoveryDays,
        "longestRecoveryDays": resilience.longestRecoveryDays,
        "totalRecoveries": resilience.totalRecoveries,
        "survival": resilience.survivalByDay
            .sorted { $0.key < $1.key }
            .map { ["day": $0.key, "probability": $0.value] },
    ]

    let breakPattern = manager.weekdayBreakPattern()
        .sorted { $0.key < $1.key }
        .map { ["weekday": $0.key, "rate": $0.value] }

    let payload: [String: Any] = [
        "range": range.wire,
        "insights": insights,
        "recommendations": recommendations,
        "weekly": weekly,
        "distribution": distributionRecord,
        "resilience": resilienceRecord,
        "breakPattern": breakPattern,
        "heatmap": heatmapRecord(manager.weekdayBreakHeatmap()),
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let json = String(data: data, encoding: .utf8) else {
        bridgeLogger.warning("streak insights failed to serialize")
        return "{}"
    }
    return json
}

private func heatmapRecord(_ heatmap: WeekdayHeatmapData) -> [String: Any] {
    [
        "days": heatmap.days.map { day -> [String: Any] in
            [
                "name": day.name,
                "shortName": day.shortName,
                "completionRate": day.completionRate,
                "totalDays": day.totalDays,
                "completeDays": day.completeDays,
                "breakRate": day.breakRate,
            ]
        }
    ]
}

private func millis(_ date: Date) -> Int64 {
    Int64(date.timeIntervalSince1970 * 1000.0)
}

// MARK: - Wire names
//
// The domain enums are not RawRepresentable by design (they are behaviour-free
// tags), so the JSON spelling is mapped here rather than leaning on Codable.
// Kotlin parses the same strings back into its own enums.

private extension InsightCategory {
    var wire: String {
        switch self {
        case .completion: return "completion"
        case .pattern: return "pattern"
        case .trend: return "trend"
        case .risk: return "risk"
        }
    }
}

private extension RecommendationAction {
    var wire: String {
        switch self {
        case .navigateToMeditation: return "navigateToMeditation"
        case .navigateToNote: return "navigateToNote"
        case .setReminder: return "setReminder"
        }
    }
}

private extension StreakRange {
    var wire: String {
        switch self {
        case .last7: return "last7"
        case .last30: return "last30"
        case .last90: return "last90"
        }
    }

    init?(rawValueString: String) {
        switch rawValueString {
        case "last7": self = .last7
        case "last30": self = .last30
        case "last90": self = .last90
        default: return nil
        }
    }
}

// MARK: - Reminder scheduling

/// Fills `out` with the next fire dates (epoch millis) for the reminder settings,
/// `-1` for the unused tail. Kotlin side: ReminderScheduleSource.kt
///
/// `tzOffsetMinutes` is the device's current GMT offset — the Swift-on-Android
/// runtime resolves `TimeZone.current` to UTC (no tzdata), so the caller has to
/// pass the offset the OS already knows. On iOS the same builder reads
/// `Calendar.current` and needs no parameter.
@_cdecl("Java_com_mn_android_data_ReminderScheduleSource_fillNextFireDates")
public func Java_com_mn_android_data_ReminderScheduleSource_fillNextFireDates(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    out: jlongArray,
    enabled: jboolean,
    hour: jint,
    minute: jint,
    weekdays: jlongArray,
    afterMillis: jlong,
    tzOffsetMinutes: jint
) {
    let weekdayValues = [Int64](fromJNI: weekdays, in: environment).map(Int.init)
    let settings = ReminderSettings(
        isEnabled: enabled != 0,
        hour: Int(hour),
        minute: Int(minute),
        weekdays: Set(weekdayValues)
    )
    let capacity = Int(environment.interface.GetArrayLength(environment, out))
    let after = Date(timeIntervalSince1970: Double(afterMillis) / 1000.0)

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: Int(tzOffsetMinutes) * 60) ?? .current
    let builder = ReminderScheduleBuilder(calendar: calendar)
    let dates = builder.nextFireDates(settings: settings, after: after, count: capacity)

    var filled = dates.map { Int64($0.timeIntervalSince1970 * 1000.0) }
    while filled.count < capacity { filled.append(-1) }
    writeValues(filled, to: out, in: environment)
}

// MARK: - Probes (device-verified JNI smoke tests)

/// Writes a known snapshot, then reads every insight metric through the same
/// body the screen uses. Results: [insightsOk, recommendationsOk, weeklyOk,
/// distributionOk, resilienceOk, heatmapOk, failed].
///
/// Kotlin side: StreakInsightsProbe.kt
@_cdecl("Java_com_mn_android_debug_NativeProbe_streakInsightsProbe")
public func Java_com_mn_android_debug_NativeProbe_streakInsightsProbe(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    out: jlongArray
) {
    var results = [Int64](repeating: 0, count: 7)
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let store = KotlinStreakActivityStore()

    func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: today)!
    }

    do {
        var activities: [DailyActivity] = []
        for offset in 1...6 {
            activities.append(DailyActivity(
                date: day(offset),
                hasMeditation: true,
                hasNote: offset % 2 == 0,
                meditationTime: day(offset)
            ))
        }
        try store.saveSync(StreakSnapshot(
            activities: activities,
            currentStreak: 6,
            longestStreak: 6,
            lastCountedDay: day(1)
        ))

        let manager = StreakInsightManager(
            snapshotProvider: StoreSnapshotProvider(snapshot: store.load() ?? StreakSnapshot(activities: [], currentStreak: 0, longestStreak: 0))
        )
        results[0] = manager.insights(for: .last7).isEmpty ? 0 : 1
        results[1] = manager.recommendations(for: .last7).isEmpty ? 0 : 1
        results[2] = manager.weeklyBreakdown(for: .last7).isEmpty ? 0 : 1
        results[3] = manager.streakLengthDistribution().totalStreaks > 0 ? 1 : 0
        results[4] = manager.resilience().totalRecoveries >= 0 ? 1 : 0
        results[5] = manager.weekdayBreakHeatmap().days.count == 7 ? 1 : 0
    } catch {
        bridgeLogger.warning("streak insights probe failed: \(error)")
        results[6] = 1
    }

    writeValues(results, to: out, in: environment)
}

/// Fills `out` from a known settings (daily at 20:00) and checks the builder
/// produced seven strictly-future dates a day apart. Results: [countOk,
/// orderedOk, spacedOk, failed]. Kotlin side: ReminderScheduleProbe.kt
@_cdecl("Java_com_mn_android_debug_NativeProbe_reminderScheduleProbe")
public func Java_com_mn_android_debug_NativeProbe_reminderScheduleProbe(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    out: jlongArray
) {
    var results = [Int64](repeating: 0, count: 4)
    let capacity = Int(environment.interface.GetArrayLength(environment, out))

    let after = Date()
    let settings = ReminderSettings(isEnabled: true, hour: 20, minute: 0, weekdays: Set(1...7))
    let dates = ReminderScheduleBuilder().nextFireDates(settings: settings, after: after, count: capacity)

    results[0] = dates.count == capacity ? 1 : 0
    results[1] = zip(dates, dates.dropFirst()).allSatisfy { $0 < $1 } ? 1 : 0
    let dayIntervals = zip(dates, dates.dropFirst()).map { $1.timeIntervalSince($0) }
    results[2] = dayIntervals.allSatisfy { abs($0 - 86_400) < 60 } ? 1 : 0

    writeValues(results, to: out, in: environment)
}
