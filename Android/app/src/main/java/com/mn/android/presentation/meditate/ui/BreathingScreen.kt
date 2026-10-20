package com.mn.android.presentation.meditate.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Air
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Create
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Spa
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.mn.android.R
import com.mn.android.infrastructure.persistence.local.settings.AnimationSettings
import com.mn.android.presentation.theme.ui.MnBackground
import com.mn.android.presentation.theme.ui.MnCloseButton
import com.mn.android.presentation.theme.ui.MnBreathing
import com.mn.android.presentation.theme.ui.MnTheme
import com.mn.core.MeditationDuration
import com.mn.core.MeditationSessionEngine
import com.mn.core.SessionDuration
import org.swift.swiftkit.core.SwiftMemoryManagement
import com.mn.android.presentation.meditate.viewmodel.BreathingSessionViewModel

internal val phaseLabel = mapOf(
    "inhale" to "Inhale",
    "holdAfterInhale" to "Hold",
    "exhale" to "Exhale",
    "holdAfterExhale" to "Hold",
)

@Composable
internal fun phaseColor(d: String): Color {
    val dark = MnTheme.colors.isDark
    return when (d) {
        "inhale" -> if (dark) MnBreathing.inhaleDark else MnBreathing.inhaleLight
        "holdAfterInhale" -> if (dark) MnBreathing.holdAfterInhaleDark else MnBreathing.holdAfterInhaleLight
        "exhale" -> if (dark) MnBreathing.exhaleDark else MnBreathing.exhaleLight
        else -> if (dark) MnBreathing.holdAfterExhaleDark else MnBreathing.holdAfterExhaleLight
    }
}

/** Minutes for the duration picker, so the sheet can spell "1 minute"/"n minutes". */
internal fun durationMinutes(d: MeditationDuration): Int = when (d) {
    MeditationDuration.oneMin(SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA) -> 1
    MeditationDuration.threeMin(SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA) -> 3
    MeditationDuration.fiveMin(SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA) -> 5
    else -> 0
}

internal val meditationDurations: List<MeditationDuration>
    get() = listOf(
        MeditationDuration.oneMin(SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA),
        MeditationDuration.threeMin(SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA),
        MeditationDuration.fiveMin(SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA),
    )

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun BreathingScreen(
    meditationId: String,
    onDone: () -> Unit,
    onBack: () -> Unit,
    onWriteNote: () -> Unit,
) {
    val vm: BreathingSessionViewModel = viewModel(key = "breath_$meditationId")
    var sheetOpen by rememberSaveable { mutableStateOf(true) }
    var selectedDuration by remember { mutableStateOf(meditationDurations[1]) }

    Box(Modifier.fillMaxSize()) {
        MnBackground()
        // iOS completion is a bare screen: no title bar, no close button.
        val finished = vm.uiState is BreathingSessionViewModel.UiState.Finished
        Column(
            Modifier.fillMaxSize().then(if (finished) Modifier else Modifier.padding(16.dp)),
        ) {
            if (!finished) {
                Box(Modifier.fillMaxWidth()) {
                    Text(
                        vm.meditationTitle,
                        color = MnTheme.textPrimary,
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    MnCloseButton(
                        onClick = { vm.stop(); onBack() },
                        modifier = Modifier.align(Alignment.CenterEnd),
                    )
                }
            }

            when (val s = vm.uiState) {
                BreathingSessionViewModel.UiState.Idle -> {
                    if (sheetOpen) {
                        DurationSheet(
                            selected = selectedDuration,
                            onSelected = { selectedDuration = it },
                            onStart = {
                                sheetOpen = false
                                vm.start(SessionDuration.init(selectedDuration, vm.arena))
                            },
                            // Dismissing the only actionable UI = leaving, and
                            // it also detaches the modal so the close button works.
                            onDismiss = onBack,
                        )
                    }
                }
                is BreathingSessionViewModel.UiState.Countdown -> {
                    CountdownOverlay(remaining = s.remaining, totalSeconds = s.totalSeconds)
                }
                is BreathingSessionViewModel.UiState.Active -> {
                    BreathContent(
                        phases = vm.breathingPhases,
                        phaseIndex = s.phaseIndex,
                        discriminator = s.discriminator,
                        phaseProgress = s.phaseProgress,
                        progress = s.progress,
                        remaining = s.remainingSeconds,
                        paused = s.paused,
                        onPauseResume = { if (s.paused) vm.resume() else vm.pause() },
                        onFinished = { vm.done() },
                    )
                }
                is BreathingSessionViewModel.UiState.Finished -> {
                    FinishedView(
                        title = vm.meditationTitle,
                        breathingStyle = vm.breathingStyle,
                        durationSeconds = s.durationSeconds,
                        onWriteNote = onWriteNote,
                        onSkip = onDone,
                    )
                }
            }
        }
    }
}
