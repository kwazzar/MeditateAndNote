package com.mn.android.ui.meditate

import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import com.mn.android.data.MeditationCatalog
import com.mn.android.data.MeditationSelection
import com.mn.android.data.SessionRecorder
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

  private val engine = MeditationSessionEngine.init(pattern(), arena)
  private var ticker: HandlerTicker? = null

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
    ) : UiState()
    data class Paused(
      val discriminator: String,
      val phaseProgress: Double,
      val progress: Float,
      val remainingSeconds: Double,
    ) : UiState()
    data class Finished(val durationSeconds: Double) : UiState()
  }

  fun start(duration: SessionDuration) {
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
    val seconds = active.map { it.getSeconds() }.orElse(0.0)
    engine.forceComplete(
      active.map { java.util.Optional.of(it) }.orElse(java.util.Optional.empty()),
      arena,
    )
    SessionRecorder.record(meditationId, seconds)
    snapshot()
  }

  private fun snapshot() { uiState = buildState() }
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
        )
      }
      is MeditationSessionEngine.SessionState.Case.Finished -> UiState.Finished(
        engine.getActiveDuration(arena).map { it.getSeconds() }.orElse(0.0)
      )
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