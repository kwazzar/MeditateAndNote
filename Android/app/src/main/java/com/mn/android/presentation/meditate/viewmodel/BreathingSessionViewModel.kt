package com.mn.android.presentation.meditate.viewmodel

import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import com.mn.android.infrastructure.persistence.local.meditation.MeditationCatalog
import com.mn.android.infrastructure.persistence.local.meditation.MeditationSelection
import com.mn.android.data.SessionRecorder
import com.mn.android.infrastructure.platform.sound.MeditationSound
import com.mn.android.infrastructure.platform.sound.SoundPlayer
import com.mn.core.BreathingPattern
import com.mn.core.BreathingStyle
import com.mn.core.MeditationSessionEngine
import com.mn.core.SessionDuration
import com.mn.core.Date
import org.swift.swiftkit.core.SwiftMemoryManagement
import java.time.Instant

class BreathingSessionViewModel(private val savedStateHandle: SavedStateHandle) : ViewModel() {

  private val meditationId: String = checkNotNull(savedStateHandle.get<String>("meditationId"))
  val arena = SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA
  val meditationTitle: String = MeditationCatalog.load().firstOrNull { it.id == meditationId }?.title ?: "Meditation"
  val breathingStyle: String = MeditationCatalog.load().firstOrNull { it.id == meditationId }?.breathingStyleRawValue ?: "box"

  /** Flat copy of Core `BreathingPattern.phases` — type discriminator + seconds. */
  data class Phase(val type: String, val durationSeconds: Double)

  val breathingPhases: List<Phase> = run {
    val pattern = BreathingStyle.init(breathingStyle, arena)
      .map { it.getPattern(arena) }
      .orElseThrow { IllegalArgumentException("Unknown style: $breathingStyle") }
    pattern.getPhases(arena).map { Phase(it.getType(arena).getDiscriminator().name.lowercase(), it.getDuration()) }
  }

  private val engine = MeditationSessionEngine.init(pattern(), arena)
  private var ticker: HandlerTicker? = null
  /** Session length, captured at start — the phase index derives from elapsed time. */
  private var totalSeconds = 0.0

  var uiState by androidx.compose.runtime.mutableStateOf<UiState>(UiState.Idle)
    private set

  sealed class UiState {
    object Idle : UiState()
    data class Countdown(val remaining: Int, val totalSeconds: Double) : UiState()
    data class Active(
      val discriminator: String,
      val phaseProgress: Double,
      val progress: Float,
      val remainingSeconds: Double,
      val paused: Boolean,
      val phaseIndex: Int,
    ) : UiState()
    data class Finished(val durationSeconds: Double) : UiState()
  }

  fun start(duration: SessionDuration) {
    totalSeconds = duration.getSeconds()
    engine.start(duration, 3L, Date.fromInstant(Instant.now(), arena), arena)
    ticker = HandlerTicker(intervalMs = 100) { tick() }
    ticker?.start()
    snapshot()
  }

  fun pause() { engine.pause(Date.fromInstant(Instant.now(), arena), arena); snapshot() }
  fun resume() { engine.resume(Date.fromInstant(Instant.now(), arena), arena); snapshot() }
  fun stop() { ticker?.cancel(); ticker = null; engine.stop(arena); snapshot() }

  fun done() {
    ticker?.cancel(); ticker = null
    val active = engine.getActiveDuration(arena)
    engine.forceComplete(
      active.map { java.util.Optional.of(it) }.orElse(java.util.Optional.empty()),
      arena,
    )
    snapshot()
  }

  private fun snapshot() {
    val next = buildState()
    playCues(lastState, next)
    lastState = next
    uiState = next
  }
  private var lastState: UiState? = null
  private var tickSecond = 0

  private fun tick() {
    try {
      val s = engine.getState(arena)
      when (val c = s.getCase(arena)) {
        is MeditationSessionEngine.SessionState.Case.Countdown -> {
          engine.tickCountdown(Date.fromInstant(Instant.now(), arena), arena)
        }
        is MeditationSessionEngine.SessionState.Case.Active -> {
          engine.tickClock(Date.fromInstant(Instant.now(), arena), arena)
          tickSecond++
          if (tickSecond >= 10) {
            tickSecond = 0
            engine.tickSecond(Date.fromInstant(Instant.now(), arena), arena)
          }
        }
        else -> {}
      }
    } catch (_: Exception) {}
    snapshot()
    if (uiState is UiState.Finished || uiState is UiState.Idle) {
      ticker?.cancel(); ticker = null
    }
  }

  /**
   * Sound cues derived from UiState diffs — iOS gets the same cues straight
   * from `MeditationSessionEngine.Event` in `MeditationViewModel.apply(_:)`;
   * the jextract port does not surface the event list, so transitions are
   * diffed at snapshot time instead (≤100 ms late, imperceptible for cues).
   * Mirrors `apply` exactly: countdown ticks, phase changes, pause/resume,
   * completion. `stop()` → Idle plays nothing, same as iOS.
   */
  private fun playCues(old: UiState?, new: UiState) {
    if (old is UiState.Countdown && new is UiState.Countdown && new.remaining < old.remaining) {
      SoundPlayer.play(MeditationSound.COUNTDOWN_TICK)
    }
    if (old !is UiState.Active && new is UiState.Active && !new.paused) {
      SoundPlayer.play(MeditationSound.fromPhase(new.discriminator))
    }
    if (old is UiState.Active && new is UiState.Active) {
      if (new.discriminator != old.discriminator) {
        SoundPlayer.play(MeditationSound.fromPhase(new.discriminator))
      }
      if (!old.paused && new.paused) SoundPlayer.play(MeditationSound.PAUSED)
      if (old.paused && !new.paused) SoundPlayer.play(MeditationSound.RESUMED)
    }
    if (new is UiState.Finished && old !is UiState.Finished) {
      SoundPlayer.play(MeditationSound.FINISHED)
      // mirrors iOS `.completed` event handler: publish session once, with the
      // full selected duration (iOS passes the same value down the event).
      SessionRecorder.record(
          meditationId,
          totalSeconds,
          java.util.TimeZone.getDefault().getOffset(System.currentTimeMillis()) / 60_000,
      )
    }
  }

  private fun buildState(): UiState {
    val s = engine.getState(arena)
    return when (val c = s.getCase(arena)) {
      is MeditationSessionEngine.SessionState.Case.Idle -> UiState.Idle
      is MeditationSessionEngine.SessionState.Case.Countdown -> UiState.Countdown(
        c.remaining.toInt(),
        c.duration.getSeconds()
      )
      is MeditationSessionEngine.SessionState.Case.Active -> {
        val clock = c.arg0
        val phase = clock.getCurrentPhase(arena)
        val disc = if (phase.isPresent) phase.get().getType(arena).getDiscriminator().name.lowercase() else "inhale"
        UiState.Active(
          discriminator = disc,
          phaseProgress = engine.phaseProgress(Date.fromInstant(Instant.now(), arena)),
          progress = engine.progress,
          remainingSeconds = c.remaining,
          paused = clock.isPaused(),
          // iOS reads `engine.currentPhaseIndex`. The jextract binding exposes
          // it too — deriving it from `remaining` was wrong: `remaining` only
          // moves on `tickSecond` (1 Hz), so the derived index lagged the
          // engine's real phase by up to a second and the path view drew the
          // ball on the previous segment.
          phaseIndex = engine.getCurrentPhaseIndex().toInt(),
        )
      }
      is MeditationSessionEngine.SessionState.Case.Finished -> UiState.Finished(totalSeconds)
    }
  }

  private fun pattern(): BreathingPattern {
    val raw = MeditationSelection.lastSelectedId?.let { id ->
      MeditationCatalog.load().firstOrNull { it.id == id }?.breathingStyleRawValue
    } ?: "4-7-8"
    return BreathingStyle.init(raw, arena)
      .map { it.getPattern(arena) }
      .orElseThrow { IllegalArgumentException("Unknown style: $raw") }
  }
}

private class HandlerTicker(
  private val intervalMs: Long,
  private val block: () -> Unit,
) {
  private val handler = Handler(Looper.getMainLooper())
  private val runnable = object : Runnable {
    override fun run() { block(); handler.postDelayed(this, intervalMs) }
  }
  fun start() { handler.post(runnable) }
  fun cancel() { handler.removeCallbacks(runnable) }
}