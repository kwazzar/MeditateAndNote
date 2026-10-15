package com.mn.android.domain.meditation.model

/**
 * Flat, Compose-safe copy of Core's `Meditation`.
 *
 * Compose never holds the jextract wrappers: every getter is a JNI round trip,
 * and the wrappers are arena-bound memory addresses, so the catalog is flattened
 * to strings once on load. Plain Kotlin — no Android, no JNI.
 */
data class MeditationUi(
    val id: String,
    val title: String,
    /** `meditation.breathingStyle.pattern.name`, e.g. "4-7-8". */
    val patternName: String,
    val description: String?,
    /** `MeditationCategory` raw value: mindfulness/breathing/sleep/focus/relaxation. */
    val category: String,
    /** `Meditation.breathingStyle.rawValue`: `4-7-8`, `Box`, `4-8`, `Custom`. */
    val breathingStyleRawValue: String,
)
