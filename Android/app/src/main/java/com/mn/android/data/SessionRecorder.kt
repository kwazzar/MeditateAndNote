package com.mn.android.data

import org.swift.swiftkit.core.SwiftMemoryManagement

/**
 * Kotlin stub for the Swift `@_cdecl` entry in
 * `SessionRecorder.swift`. Records a completed session through
 * `KotlinMeditationSessionStore` — Swift encodes the payload JSON,
 * so Kotlin never touches the serialization shape.
 */
object SessionRecorder {

    /**
     * The JNI library is loaded by the *generated* classes' static
     * initialisers — they own the library name, so the name never has to be
     * repeated here. This hand-written `external fun` has no such hook of its
     * own: the app used to work only because some other generated class ran
     * first, and a caller that reached `record` before that got
     * `UnsatisfiedLinkError`. Touching one generated class loads the library
     * (and keeps it rename-proof).
     */
    init {
        com.mn.core.MeditationDuration.oneMin(SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA)
    }

    external fun record(meditationId: String, seconds: Double, tzOffsetMinutes: Int): Long
}
