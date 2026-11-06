package com.mn.android.sound

import com.mn.android.domain.meditation.SessionCue
import com.mn.android.domain.meditation.SoundPlayer

/**
 * Records the cues instead of playing them. A test that only needs "a sound
 * happened" does not need the Android sound stack.
 */
class RecordingSoundPlayer : SoundPlayer {
    val played: MutableList<SessionCue> = mutableListOf()

    override fun play(cue: SessionCue) {
        played += cue
    }
}
