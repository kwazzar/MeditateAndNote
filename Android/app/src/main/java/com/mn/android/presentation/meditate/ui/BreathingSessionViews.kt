package com.mn.android.presentation.meditate.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Air
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Create
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Spa
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
import com.mn.android.R
import com.mn.android.infrastructure.persistence.local.settings.AnimationSettings
import com.mn.android.presentation.theme.ui.MnBreathing
import com.mn.android.presentation.theme.ui.MnTheme
import com.mn.core.MeditationDuration
import com.mn.android.presentation.meditate.viewmodel.BreathingSessionViewModel

/** Session-phase views for BreathingScreen: duration sheet, countdown, active
 *  session, rings animation, progress, and the finished summary. */

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
internal fun DurationSheet(
    selected: MeditationDuration,
    onSelected: (MeditationDuration) -> Unit,
    onStart: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = {}, containerColor = MnTheme.background) {
        Column(Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                "Duration",
                color = MnTheme.textPrimary,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(16.dp))
            meditationDurations.forEach { d ->
                Row(
                    Modifier.fillMaxWidth().padding(vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    RadioButton(
                        selected = d == selected,
                        onClick = { onSelected(d) },
                        colors = RadioButtonDefaults.colors(selectedColor = MnTheme.accentButton),
                    )
                    Text(durationLabel(d), color = MnTheme.textPrimary, modifier = Modifier.weight(1f))
                }
            }
            Spacer(Modifier.height(16.dp))
            Button(
                onClick = onStart,
                colors = ButtonDefaults.buttonColors(containerColor = MnTheme.accentButton),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Start", color = MnTheme.buttonText, fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}

@Composable
internal fun CountdownOverlay(remaining: Int, totalSeconds: Double) {
    Column(
        Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            remaining.toString(),
            color = MnTheme.textPrimary.copy(alpha = 0.35f),
            style = MaterialTheme.typography.displayLarge,
            fontWeight = FontWeight.Light,
        )
        Text(
            String.format("%d:%02d", totalSeconds.toInt() / 60, totalSeconds.toInt() % 60),
            color = MnTheme.textSecondary,
        )
    }
}

@Composable
internal fun BreathContent(
    phases: List<BreathingSessionViewModel.Phase>,
    phaseIndex: Int,
    discriminator: String,
    phaseProgress: Double,
    progress: Float,
    remaining: Double,
    paused: Boolean,
    onPauseResume: () -> Unit,
    onFinished: () -> Unit,
) {
    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            phaseLabel[discriminator] ?: discriminator,
            color = phaseColor(discriminator),
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            String.format("%d:%02d", remaining.toInt() / 60, remaining.toInt() % 60),
            color = MnTheme.textSecondary,
        )
        Spacer(Modifier.height(8.dp))
        // iOS MeditationView.landscapeLayout: animation + progress in one
        // HStack (spaced 32), centered; portrait keeps the column.
        val landscape = LocalConfiguration.current.orientation ==
            android.content.res.Configuration.ORIENTATION_LANDSCAPE
        if (landscape) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
            ) {
                if (AnimationSettings.style == AnimationSettings.RINGS) {
                    BreathingRings(discriminator, phaseProgress)
                } else {
                    BreathingPathView(phases = phases, phaseIndex = phaseIndex, phaseProgress = phaseProgress)
                }
                Spacer(Modifier.width(32.dp))
                ProgressBar(progress = progress, modifier = Modifier.width(160.dp))
            }
        } else {
            if (AnimationSettings.style == AnimationSettings.RINGS) {
                BreathingRings(discriminator, phaseProgress)
            } else {
                BreathingPathView(phases = phases, phaseIndex = phaseIndex, phaseProgress = phaseProgress)
            }
            Spacer(Modifier.height(16.dp))
            ProgressBar(progress = progress)
        }
        Spacer(Modifier.height(16.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Button(
                onClick = onPauseResume,
                colors = ButtonDefaults.buttonColors(containerColor = MnTheme.accentButton),
            ) {
                Text(
                    if (paused) "Resume" else "Pause",
                    color = MnTheme.buttonText,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            Button(
                onClick = onFinished,
                colors = ButtonDefaults.buttonColors(containerColor = MnTheme.streakSuccess),
            ) {
                Text("Done", color = MnTheme.buttonText, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun BreathingRings(discriminator: String, phaseProgress: Double) {
    val inf = rememberInfiniteTransition(label = "breath")
    val pulse = inf.animateFloat(
        initialValue = 0.95f,
        targetValue = 1.05f,
        animationSpec = infiniteRepeatable(
            animation = tween(4000),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )
    val targetScale = when (discriminator) {
        "inhale" -> 1.0 + 0.35 * phaseProgress
        "exhale" -> 1.35 - 0.35 * phaseProgress
        else -> if (discriminator == "inhale") 1.35 else 0.65
    }
    val density = LocalDensity.current
    val sizePx = with(density) { 250.dp.toPx() }
    val base = (targetScale * pulse.value)
    Canvas(Modifier.size(250.dp)) {
        repeat(5) { i ->
            val lag = i * 0.08
            val scale = ((base - 1) * (1 - lag).coerceIn(0.4, 1.0) + 1).toFloat()
            val opacity = (0.25 + i * 0.12).toFloat().coerceIn(0.2f, 0.9f)
            drawCircle(
                color = phaseColor(discriminator).copy(alpha = opacity),
                radius = (sizePx * 0.4f * scale) / 2f,
                center = Offset(sizePx / 2, sizePx / 2),
                style = Stroke(width = with(density) { 3.dp.toPx() }),
            )
        }
    }
}

@Composable
private fun ProgressBar(progress: Float, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().height(12.dp).background(MnTheme.cardBackground)) {
        Box(
            Modifier.fillMaxWidth(progress.coerceIn(0f, 1f)).height(12.dp)
                .background(MnTheme.streakActiveNote),
        )
    }
}

@Composable
internal fun FinishedView(
    title: String,
    breathingStyle: String,
    durationSeconds: Double,
    onWriteNote: () -> Unit,
    onSkip: () -> Unit,
) {
    Column(
        Modifier.fillMaxSize().padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            Icons.Outlined.CheckCircle,
            contentDescription = null,
            tint = MnTheme.streakSuccess,
            modifier = Modifier.size(64.dp),
        )
        Spacer(Modifier.height(16.dp))
        Text(
            "Well Done!",
            color = MnTheme.textPrimary,
            style = MaterialTheme.typography.displaySmall,
            fontWeight = FontWeight.Bold,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "You completed your meditation session",
            color = MnTheme.textSecondary,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(24.dp))
        Column(
            Modifier.fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(MnTheme.cardBackground)
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            InfoRow(Icons.Outlined.Spa, title)
            InfoRow(Icons.Outlined.Air, breathingStyle)
            InfoRow(Icons.Outlined.Schedule, formatDuration(durationSeconds))
        }
        Spacer(Modifier.height(24.dp))
        Button(
            onClick = onWriteNote,
            colors = ButtonDefaults.buttonColors(containerColor = MnTheme.accentButton),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Icon(
                Icons.Outlined.Create,
                contentDescription = null,
                tint = MnTheme.buttonText,
            )
            Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.write_a_note), color = MnTheme.buttonText, fontWeight = FontWeight.SemiBold)
        }
        TextButton(onClick = onSkip) {
            Text(stringResource(R.string.skip_for_now), color = MnTheme.textSecondary)
        }
    }
}

@Composable
private fun InfoRow(icon: ImageVector, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = MnTheme.textSecondary, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(12.dp))
        Text(label, color = MnTheme.textPrimary, style = MaterialTheme.typography.bodyLarge)
    }
}

private fun formatDuration(seconds: Double): String {
    val mins = seconds.toInt() / 60
    val secs = seconds.toInt() % 60
    return if (secs == 0) "$mins min" else "$mins min $secs sec"
}
