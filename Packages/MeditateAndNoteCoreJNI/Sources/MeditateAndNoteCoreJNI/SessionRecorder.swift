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

@_cdecl("Java_com_mn_android_data_SessionRecorder_record")
public func Java_com_mn_android_data_SessionRecorder_record(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    meditationId: jstring?,
    seconds: jdouble
) -> jlong {
    let id = String(fromJNI: meditationId, in: environment)
    let store = KotlinMeditationSessionStore()
    let session = MeditationSession(
        meditationId: MeditationID(rawValue: id),
        duration: SessionDuration(seconds: seconds)
    )
    do {
        try store.saveSync(session)
        return 1
    } catch {
        return 0
    }
}