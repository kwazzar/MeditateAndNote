package com.mn.android.domain.meditation

/**
 * A cue the session plays. Domain-level, so the ViewModel never names an
 * Android resource — the infrastructure maps a cue to the sound file.
 */
enum class SessionCue {
    INHALE,
    HOLD,
    EXHALE,
    COUNTDOWN_TICK,
    PAUSED,
    RESUMED,
    FINISHED;

    companion object {
        /** Maps a Core `BreathingPhaseType` discriminator to a cue. */
        fun fromPhase(discriminator: String): SessionCue = when (discriminator) {
            "inhale" -> INHALE
            "exhale" -> EXHALE
            else -> HOLD // holdAfterInhale + holdAfterExhale
        }
    }
}
