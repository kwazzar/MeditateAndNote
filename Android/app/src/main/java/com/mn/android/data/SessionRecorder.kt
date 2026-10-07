package com.mn.android.data

/**
 * Kotlin stub for the Swift `@_cdecl` entry in
 * `SessionRecorder.swift`. Records a completed session through
 * `KotlinMeditationSessionStore` — Swift encodes the payload JSON,
 * so Kotlin never touches the serialization shape.
 */
object SessionRecorder {
    external fun record(meditationId: String, seconds: Double): Long
}