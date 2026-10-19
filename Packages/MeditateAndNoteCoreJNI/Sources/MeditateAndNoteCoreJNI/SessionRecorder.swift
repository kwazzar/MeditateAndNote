//
//  SessionRecorder.swift
//  MeditateAndNoteCoreJNI
//
//  Kotlin calls this on session completion: Swift builds a `MeditationSession`
//  (JSON payload written here, never parsed in Kotlin) and saves it through
//  the Kotlin session store — the same shape the iOS `CoreDataSessionStore`
//  write path uses.
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

private let logger = Logger(subsystem: "com.mn.core", category: "SessionRecorder")

/// Marks a meditation on today's `DailyActivity` and updates the streak the
/// same way `StreakEngine.markMeditationCompleted` + `updateStreak` do on iOS.
/// Lives next to `record` because Android has no DomainEventBus yet — on iOS
/// this runs inside `StreakTracker.handle(.meditationCompleted)`; here the
/// recording event is the only natural place the session and the streak meet.
func streakMarkMeditation(
    _ snapshot: StreakSnapshot,
    completedAt: Date,
    calendar: Calendar = .current
) -> StreakSnapshot {
    let key = calendar.startOfDay(for: completedAt)
    var activities = snapshot.activities

    if let index = activities.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: key) }) {
        activities[index].markMeditation(at: completedAt)
    } else {
        var activity = DailyActivity(date: key, hasMeditation: false, hasNote: false)
        activity.markMeditation(at: completedAt)
        activities.append(activity)
    }

    guard let today = activities.first(where: { calendar.isDate($0.date, inSameDayAs: key) }),
          today.isComplete,
          snapshot.lastCountedDay.map({ !calendar.isDate($0, inSameDayAs: key) }) ?? true
    else {
        return StreakSnapshot(
            activities: activities,
            currentStreak: snapshot.currentStreak,
            longestStreak: snapshot.longestStreak,
            lastCountedDay: snapshot.lastCountedDay
        )
    }

    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: key) else {
        return StreakSnapshot(
            activities: activities,
            currentStreak: snapshot.currentStreak,
            longestStreak: snapshot.longestStreak,
            lastCountedDay: snapshot.lastCountedDay
        )
    }
    let yesterdayComplete = activities.first { calendar.isDate($0.date, inSameDayAs: yesterday) }?
        .isComplete ?? false
    let streak = (yesterdayComplete && snapshot.currentStreak > 0) ? snapshot.currentStreak + 1 : 1
    return StreakSnapshot(
        activities: activities,
        currentStreak: streak,
        longestStreak: max(snapshot.longestStreak, streak),
        lastCountedDay: key
    )
}

@_cdecl("Java_com_mn_android_data_SessionRecorder_record")
public func Java_com_mn_android_data_SessionRecorder_record(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    meditationId: jstring?,
    seconds: jdouble,
    tzOffsetMinutes: jint
) -> jlong {
    let id = String(fromJNI: meditationId, in: environment)
    let store = KotlinMeditationSessionStore()
    let session = MeditationSession(
        meditationId: MeditationID(rawValue: id),
        duration: SessionDuration(seconds: seconds)
    )
    // Swift-on-Android resolves TimeZone.current to UTC (no tzdata), so the
    // caller passes the JVM's current offset — same rule as ReminderSchedule.
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: Int(tzOffsetMinutes) * 60) ?? .current
    do {
        try store.saveSync(session)
        // Best effort: the session payload is already persisted; a streak-write
        // failure only delays the streak header update until the next save.
        do {
            let streak = KotlinStreakActivityStore()
            let marked = streakMarkMeditation(
                streak.load()
                    ?? StreakSnapshot(activities: [], currentStreak: 0, longestStreak: 0, lastCountedDay: nil),
                completedAt: session.completedAt,
                calendar: calendar
            )
            try streak.saveSync(marked)
        } catch {
            logger.warning("SessionRecorder: streak update failed: \(error)")
        }
        return 1
    } catch {
        return 0
    }
}