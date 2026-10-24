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