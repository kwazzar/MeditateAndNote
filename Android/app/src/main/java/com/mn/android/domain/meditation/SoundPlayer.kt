package com.mn.android.domain.meditation

/**
 * Plays the session cues. The interface is the domain's view of the sound
 * layer; the implementation owns the Android resources.
 */
interface SoundPlayer {
    fun play(cue: SessionCue)
}
