package com.mn.android.presentation.meditate.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Air
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Eco
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.outlined.Create
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
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
    onDismiss: () -> Unit,
) {
    // iOS TimeMeditationSheet: top spacing, wheel picker, "Select Duration",
    // full-width Start button, top-rounded slab.
    ModalBottomSheet(
        // Swipe-down must leave the composition (caller pops the screen) —
        // an empty handler leaves the modal window attached and it eats
        // every tap on the close button behind the sheet.
        onDismissRequest = onDismiss,
        // iOS floats the wheel over the game background: no slab, no scrim,
        // only the selection pill is drawn.
        containerColor = Color.Transparent,
        scrimColor = Color.Transparent,
        dragHandle = null,
    ) {
        val domeColor = MnTheme.toolbarBackground
        Column(
            Modifier
                .drawBehind {
                    // iOS `CustomTopRoundedShape`: a quad-curved dome behind the
                    // sheet, apex ~65pt, shoulders at 140pt, filled with
                    // `toolbarBackground`.
                    val shoulder = 140.dp.toPx()
                    val apex = -10.dp.toPx()
                    val path = Path().apply {
                        moveTo(0f, size.height)
                        lineTo(0f, shoulder)
                        quadraticBezierTo(size.width / 2f, apex, size.width, shoulder)
                        lineTo(size.width, size.height)
                        close()
                    }
                    drawPath(path, domeColor)
                }
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(64.dp))
            meditationDurations.forEach { d ->
                val mins = durationMinutes(d)
                val isSelected = d == selected
                // iOS wheel picker: the centre row is larger and brighter, the
                // selection pill sits behind it.
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(38.dp)
                        .clickable { onSelected(d) }
                        .background(
                            if (isSelected) MnTheme.divider else Color.Transparent,
                            RoundedCornerShape(19.dp),
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        if (mins == 1) "1 minute" else "$mins minutes",
                        color = if (isSelected) MnTheme.textPrimary else MnTheme.textSecondary,
                        fontSize = if (isSelected) 24.sp else 18.sp,
                        fontWeight = FontWeight.Normal,
                        textAlign = TextAlign.Center,
                    )
                }
            }
            Spacer(Modifier.height(20.dp))
            Text(
                "Select Duration",
                color = MnTheme.textPrimary,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(20.dp))
            Button(
                onClick = onStart,
                colors = ButtonDefaults.buttonColors(containerColor = MnTheme.accentButton),
                modifier = Modifier.fillMaxWidth().height(50.dp),
                shape = RoundedCornerShape(12.dp),
            ) {
                Text("Start Meditation", color = MnTheme.buttonText, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(24.dp))
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
            color = MnTheme.accentColor.copy(alpha = 0.35f),
            fontSize = 120.sp,
            fontWeight = FontWeight.Light,
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
    val landscape = LocalConfiguration.current.orientation ==
        android.content.res.Configuration.ORIENTATION_LANDSCAPE
    val size = if (landscape) {
        (LocalConfiguration.current.screenHeightDp * 0.55).toInt().coerceIn(120, 200)
    } else {
        (LocalConfiguration.current.screenHeightDp * 0.55).toInt().coerceIn(120, 250)
    }
    val currentDuration = phases.getOrElse(phaseIndex) { phases.firstOrNull() }?.durationSeconds ?: 0.0
    val phaseRemaining = (currentDuration * (1 - phaseProgress)).toInt().coerceAtLeast(0)
    val buttonLabel = if (paused) "Resume" else "Tap to Pause"

    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        // iOS MeditationView.meditationPlan: only phase name.
        Text(
            phaseLabel[discriminator] ?: discriminator,
            color = phaseColor(discriminator),
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(8.dp))
        // Rendered at bottom, like iOS? iOS remaining only in progress+ring center.
        // iOS MeditationView chronology: animation then progress.
        Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
            if (AnimationSettings.style == AnimationSettings.RINGS) {
                BreathingRings(discriminator, phaseProgress, phaseRemaining, size.dp)
            } else {
                BreathingPathView(
                    phases = phases,
                    phaseIndex = phaseIndex,
                    phaseProgress = phaseProgress,
                    modifier = Modifier.height(size.dp),
                )
            }
        }
        Spacer(Modifier.height(16.dp))
        ProgressCapsule(
            progress = progress,
            color = phaseColor(discriminator).copy(alpha = 0.8f),
            label = buttonLabel,
            onClick = {
                if (remaining <= 0.5) onFinished()
                else onPauseResume()
            },
            modifier = Modifier.widthIn(max = 326.dp).fillMaxWidth(),
        )
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun BreathingRings(
    discriminator: String,
    phaseProgress: Double,
    phaseRemaining: Int,
    size: androidx.compose.ui.unit.Dp,
) {
    val color = phaseColor(discriminator)
    val hasPhase = discriminator in setOf("inhale", "holdafterinhale", "exhale", "holdafterexhale") || true
    val ringCount = 5
    val density = LocalDensity.current
    val sizePx = with(density) { size.toPx() }
    // iOS ConcentricRing baseSize = 120 + i*30 (diameters), expanded by 1+0.3*(i+1).
    Box(contentAlignment = Alignment.Center, modifier = Modifier.size(size)) {
        Canvas(Modifier.size(size)) {
            for (i in 0 until ringCount) {
                val base = (120 + i * 30)
                val expansion = 1.0 + 0.3 * (i + 1)
                val ringSize = when {
                    discriminator == "inhale" ->
                        base + (base * expansion - base) * phaseProgress
                    discriminator == "exhale" ->
                        base + (base * expansion - base) * (1.0 - phaseProgress)
                    discriminator == "holdafterinhale" -> base * expansion
                    discriminator == "holdafterexhale" -> base.toDouble()
                    else -> base.toDouble()
                }.toFloat() * (sizePx / 250f)
                val baseOpacity = 0.8 - (i * 0.15)
                val opacity = when (discriminator) {
                    "inhale" -> baseOpacity * (0.3 + 0.7 * phaseProgress)
                    "exhale" -> baseOpacity * (1.0 - 0.7 * phaseProgress)
                    "holdafterinhale" -> baseOpacity
                    "holdafterexhale" -> baseOpacity * 0.3
                    else -> 0.3
                }.toFloat().coerceIn(0.1f, 1f)
                val ringLineWidth = when (discriminator) {
                    "inhale" -> 3f + (phaseProgress.toFloat() * 2f)
                    "exhale" -> 3f + ((1f - phaseProgress.toFloat()) * 2f)
                    "holdafterinhale" -> 5f
                    else -> 3f
                }
                drawCircle(
                    color = color.copy(alpha = opacity),
                    radius = (ringSize / 2f).coerceAtLeast(1f),
                    center = Offset(sizePx / 2f, sizePx / 2f),
                    style = Stroke(width = with(density) { ringLineWidth.dp.toPx() }),
                )
            }
            // Inner filled circle (iOS: 0.32 * size).
            drawCircle(
                color = color.copy(alpha = 0.8f),
                radius = (sizePx * 0.32f / 2f),
                center = Offset(sizePx / 2f, sizePx / 2f),
            )
        }
        Text(
            "$phaseRemaining",
            color = MnTheme.textPrimary,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Normal,
        )
    }
}

@Composable
private fun ProgressCapsule(
    progress: Float,
    color: Color,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // iOS MeditationProgressView: a 44pt capsule (streakCellBackground), phase
    // tint filled from the leading edge, 24pt bold label on top. Tapping the
    // whole capsule pauses — it is not a Material button.
    Box(
        modifier
            .height(44.dp)
            .clip(RoundedCornerShape(50))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(44.dp)
                .background(MnTheme.cardBackground),
        )
        Box(
            Modifier
                .align(Alignment.CenterStart)
                .fillMaxWidth(progress.coerceIn(0f, 1f))
                .height(44.dp)
                .background(color),
        )
        Text(
            label,
            color = MnTheme.textPrimary,
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
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
    // iOS MeditationCompletionView: Spacer → header → info → Spacer → actions
    // pinned above the bottom inset.
    Column(
        Modifier.fillMaxSize().padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f))
        Icon(
            Icons.Filled.CheckCircle,
            contentDescription = null,
            tint = MnTheme.streakSuccess,
            modifier = Modifier.size(64.dp),
        )
        Spacer(Modifier.height(16.dp))
        Text(
            "Well Done!",
            color = MnTheme.textPrimary,
            fontSize = 32.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(16.dp))
        Text(
            "You completed your meditation session",
            color = MnTheme.textSecondary,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(32.dp))
        Column(
            Modifier.fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(MnTheme.cardBackground)
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            InfoRow(Icons.Filled.Eco, title)
            InfoRow(Icons.Filled.Air, breathingStyle)
            InfoRow(Icons.Filled.Schedule, formatDuration(durationSeconds))
        }
        Spacer(Modifier.weight(1f))
        Button(
            onClick = onWriteNote,
            colors = ButtonDefaults.buttonColors(containerColor = MnTheme.accentButton),
            shape = RoundedCornerShape(14.dp),
            contentPadding = PaddingValues(vertical = 16.dp),
            modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
        ) {
            Icon(
                Icons.Outlined.Create,
                contentDescription = null,
                tint = MnTheme.buttonText,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                stringResource(R.string.write_a_note),
                color = MnTheme.buttonText,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )
        }
        Box(
            Modifier
                .clip(RoundedCornerShape(8.dp))
                .clickable(onClick = onSkip)
                .padding(vertical = 8.dp),
        ) {
            Text(
                stringResource(R.string.skip_for_now),
                color = MnTheme.textSecondary,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
        Spacer(Modifier.height(48.dp))
    }
}

@Composable
private fun InfoRow(icon: ImageVector, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = MnTheme.textSecondary, modifier = Modifier.size(16.dp).width(24.dp))
        Spacer(Modifier.width(12.dp))
        Text(label, color = MnTheme.textPrimary, style = MaterialTheme.typography.bodyLarge)
        Spacer(Modifier.weight(1f))
    }
}

private fun formatDuration(seconds: Double): String {
    val mins = seconds.toInt() / 60
    val secs = seconds.toInt() % 60
    return if (secs == 0) "$mins min" else "$mins min $secs sec"
}
