package com.mn.android.infrastructure.platform.sound

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import com.mn.android.R
import com.mn.android.domain.meditation.SessionCue
import com.mn.android.domain.meditation.SoundPlayer
import com.mn.android.infrastructure.persistence.local.settings.SoundSettings

/**
 * Port of iOS `MeditationSound` (`Services/Sound/SoundPlayer.swift`): every
 * playable session cue and its bundled resource. The two holds share one file
 * and the iOS resource list has no mp3 entry — mirrored exactly.
 */
enum class MeditationSound(val resId: Int) {
    PAUSED(R.raw.meditation_paused),
    RESUMED(R.raw.meditation_resumed),
    FINISHED(R.raw.meditation_finished),
    COUNTDOWN_TICK(R.raw.meditation_countdown),
    PHASE_INHALE(R.raw.breath_inhale),
    PHASE_HOLD(R.raw.breath_hold),
    PHASE_EXHALE(R.raw.breath_exhale),
    ;

    companion object {
        /** The domain cue's Android resource. */
        fun of(cue: SessionCue): MeditationSound = when (cue) {
            SessionCue.INHALE -> PHASE_INHALE
            SessionCue.HOLD -> PHASE_HOLD
            SessionCue.EXHALE -> PHASE_EXHALE
            SessionCue.COUNTDOWN_TICK -> COUNTDOWN_TICK
            SessionCue.PAUSED -> PAUSED
            SessionCue.RESUMED -> RESUMED
            SessionCue.FINISHED -> FINISHED
        }
    }
}

/**
 * Port of iOS `SoundPlayer.shared`: plays short session cues at the persisted
 * `SoundSettings.volume`. SoundPool instead of AVAudioPlayer — every asset is
 * ≤4.5 s PCM, exactly what SoundPool is for (low-latency one-shots, no
 * prepare dance). Loads are async; a cue played before its load completes is
 * dropped, same as iOS drops a missing bundle resource.
 */
object SoundPlayerImpl : SoundPlayer {

    @Volatile
    private var appContext: Context? = null
    @Volatile
    private var pool: SoundPool? = null
    private val sampleIds = HashMap<MeditationSound, Int>()
    private val loaded = HashSet<Int>()

    fun configure(context: Context) {
        if (appContext == null) {
            synchronized(this) {
                if (appContext == null) {
                    appContext = context.applicationContext
                }
            }
        }
    }

    override fun play(cue: SessionCue) = play(MeditationSound.of(cue))

    fun play(sound: MeditationSound) {
        val context = appContext ?: return
        val soundPool = pool ?: buildPool().also { pool = it }
        val id = sampleIds.getOrPut(sound) {
            soundPool.load(context, sound.resId, 1).also { sampleId ->
                soundPool.setOnLoadCompleteListener { _, loadedId, status ->
                    if (status == 0) loaded.add(loadedId)
                }
            }
        }
        if (id in loaded) {
            val volume = SoundSettings.volume
            soundPool.play(id, volume, volume, 1, 0, 1f)
        }
    }

    private fun buildPool(): SoundPool = SoundPool.Builder()
        .setMaxStreams(4)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        .build()
}
