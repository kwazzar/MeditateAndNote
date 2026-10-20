package com.mn.android.presentation.meditate.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
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
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.EaseInOut
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
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
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
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
    // full-width Start button, on a `CustomTopRoundedShape` dome.
    val landscape = LocalConfiguration.current.orientation ==
        android.content.res.Configuration.ORIENTATION_LANDSCAPE
    // iOS proportions: 72 pt of empty space above a 150 pt wheel, the selected
    // row in the middle of the wheel. The landscape sheet is shorter — the
    // screen is.
    val topSpace = if (landscape) 24.dp else 72.dp
    val pickerHeight = if (landscape) 120.dp else 150.dp
    // iOS puts the dome's shoulders 140 pt below the sheet's top and the
    // selected row 147 pt below it — the pill therefore always sits on the
    // slab, never on its edge.
    val shoulder = topSpace + pickerHeight / 2 - 7.dp
    val domeColor = MnTheme.toolbarBackground

    // The half-expanded anchor would clip the sheet in landscape: the content
    // is taller than the anchor, and the sheet would stay there.
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        sheetState = sheetState,
        // Swipe-down must leave the composition (caller pops the screen) —
        // an empty handler leaves the modal window attached and it eats
        // every tap on the close button behind the sheet.
        onDismissRequest = onDismiss,
        // iOS floats the wheel over the game background: no slab, no scrim,
        // only the dome is drawn.
        containerColor = Color.Transparent,
        scrimColor = Color.Transparent,
        dragHandle = null,
        // The dome reaches the bottom of the screen (iOS ignores the safe
        // area), so the sheet must not reserve the navigation bar inset.
        contentWindowInsets = { WindowInsets(0) },
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .drawWithContent {
                    // iOS `CustomTopRoundedShape`: a quad-curved dome, filled
                    // with `toolbarBackground` and clipping the content to the
                    // same path — `.background(shape.fill())` + `.clipShape(shape)`.
                    val path = domePath(size, shoulder.toPx(), (-10).dp.toPx())
                    drawPath(path, domeColor)
                    val content = this
                    clipPath(path) { content.drawContent() }
                },
        ) {
            Column(
                Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Spacer(Modifier.height(topSpace))
                // The wheel: the selected row in its middle, the other two
                // above and below it.
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(pickerHeight),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        meditationDurations.forEach { d ->
                            val mins = durationMinutes(d)
                            val isSelected = d == selected
                            // iOS wheel picker: the centre row is larger and
                            // brighter, the selection pill sits behind it.
                            Box(
                                Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 14.dp)
                                    .height(32.dp)
                                    .clickable { onSelected(d) }
                                    .background(
                                        if (isSelected) MnTheme.divider else Color.Transparent,
                                        RoundedCornerShape(16.dp),
                                    ),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    pluralStringResource(R.plurals.minutes, mins, mins),
                                    color = if (isSelected) MnTheme.textPrimary else MnTheme.textSecondary,
                                    fontSize = if (isSelected) 22.sp else 18.sp,
                                    fontWeight = FontWeight.Normal,
                                    textAlign = TextAlign.Center,
                                )
                            }
                        }
                    }
                }
                Spacer(Modifier.height(25.dp))
                Text(
                    stringResource(R.string.select_duration),
                    color = MnTheme.textPrimary,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
                Spacer(Modifier.height(25.dp))
                Button(
                    onClick = onStart,
                    colors = ButtonDefaults.buttonColors(containerColor = MnTheme.accentButton),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                        .height(50.dp),
                    shape = RoundedCornerShape(12.dp),
                ) {
                    Text(stringResource(R.string.start_meditation), color = MnTheme.buttonText, fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.height(32.dp))
            }
        }
    }
}

/** iOS `CustomTopRoundedShape`: a quad curve from (0, shoulder) to (width,
 *  shoulder) with the control point at (width/2, apex) — the dome the sheet
 *  is drawn on. */
private fun domePath(size: Size, shoulder: Float, apex: Float): Path = Path().apply {
    moveTo(0f, size.height)
    lineTo(0f, shoulder)
    quadraticTo(size.width / 2f, apex, size.width, shoulder)
    lineTo(size.width, size.height)
    close()
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
                BreathingRings(
                    discriminator = discriminator,
                    phaseIndex = phaseIndex,
                    phaseRemaining = phaseRemaining,
                    phaseDurationSeconds = currentDuration,
                    size = size.dp,
                )
            } else {
                BreathingPathView(
                    phases = phases,
                    phaseIndex = phaseIndex,
                    phaseProgress = phaseProgress,
                    discriminator = discriminator,
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

/**
 * Port of iOS `ConcentricRing` (5 rings around a filled core).
 *
 * iOS drives every ring with
 * `.animation(.easeInOut(duration: phase.duration * 0.8).delay(index * 0.2),
 * value: phaseProgress)`: the ring eases from the phase-start size to the
 * phase-end size over 80% of the phase, and each ring starts 0.2 s after the
 * previous one (the ripple). The engine only publishes `phaseProgress` every
 * 100 ms, so the animation layer is what turns those 10 Hz steps into
 * continuous motion — without it the rings jump.
 *
 * Same spec here: one `Animatable` per ring, restarted on every phase change,
 * so the eased curve is interpolated by the framework at display rate.
 */
@Composable
private fun BreathingRings(
    discriminator: String,
    phaseIndex: Int,
    phaseRemaining: Int,
    phaseDurationSeconds: Double,
    size: androidx.compose.ui.unit.Dp,
) {
    // iOS `.animation(.easeInOut(duration: 0.3), value: breathingColor)`:
    // the ring colour cross-fades over 0.3 s when the phase changes.
    val color by animateColorAsState(
        targetValue = phaseColor(discriminator),
        animationSpec = tween(durationMillis = 300, easing = EaseInOut),
        label = "breathColor",
    )
    val ringCount = 5
    val density = LocalDensity.current
    val sizePx = with(density) { size.toPx() }
    val scale = sizePx / 250f
    val moving = discriminator == "inhale" || discriminator == "exhale"

    // Eased phase progress per ring: 0 = phase start, 1 = phase end.
    val eased = remember { List(ringCount) { Animatable(0f) } }
    LaunchedEffect(discriminator, phaseIndex) {
        coroutineScope {
            eased.forEachIndexed { index, anim ->
                launch {
                    anim.snapTo(if (moving) 0f else 1f)
                    if (moving) {
                        anim.animateTo(
                            targetValue = 1f,
                            animationSpec = tween(
                                durationMillis = (phaseDurationSeconds * 800).toInt(),
                                delayMillis = index * 200,
                                easing = EaseInOut,
                            ),
                        )
                    }
                }
            }
        }
    }

    // iOS ConcentricRing baseSize = 120 + i*30 (diameters), expanded by 1+0.3*(i+1).
    Box(contentAlignment = Alignment.Center, modifier = Modifier.size(size)) {
        Canvas(Modifier.size(size)) {
            for (i in 0 until ringCount) {
                val p = eased[i].value
                val base = (120 + i * 30).toFloat()
                val expansion = 1f + 0.3f * (i + 1)
                val ringSize = when (discriminator) {
                    "inhale" -> base + (base * expansion - base) * p
                    "exhale" -> base + (base * expansion - base) * (1f - p)
                    "holdafterinhale" -> base * expansion
                    else -> base
                } * scale
                val baseOpacity = 0.8f - (i * 0.15f)
                val opacity = when (discriminator) {
                    "inhale" -> baseOpacity * (0.3f + 0.7f * p)
                    "exhale" -> baseOpacity * (1f - 0.7f * p)
                    "holdafterinhale" -> baseOpacity
                    else -> baseOpacity * 0.3f
                }.coerceIn(0.1f, 1f)
                val ringLineWidth = when (discriminator) {
                    "inhale" -> 3f + 2f * p
                    "exhale" -> 3f + 2f * (1f - p)
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
            stringResource(R.string.number_format, phaseRemaining),
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
    // iOS animates the fill with `.animation(.linear(duration: 0.3), value: progress)`;
    // the engine publishes progress at 10 Hz, so without the tween the fill
    // edge creeps in visible steps.
    val fill by animateFloatAsState(
        targetValue = progress.coerceIn(0f, 1f),
        animationSpec = tween(durationMillis = 300, easing = LinearEasing),
        label = "progressFill",
    )
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
                .fillMaxWidth(fill)
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
            stringResource(R.string.well_done),
            color = MnTheme.textPrimary,
            fontSize = 32.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(16.dp))
        Text(
            stringResource(R.string.session_completed),
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
            // iOS: 16pt vertical padding around a 17pt label = 49pt tall.
            modifier = Modifier.fillMaxWidth().heightIn(min = 50.dp),
        ) {
            Icon(
                // iOS `square.and.pencil` — a note sheet with a pencil, not a
                // bare pencil. The iOS label applies `.font(.headline)` to the
                // whole HStack, so the glyph is 17pt too.
                Icons.Outlined.EditNote,
                contentDescription = null,
                tint = MnTheme.buttonText,
                modifier = Modifier.size(17.dp),
            )
            Spacer(Modifier.width(8.dp))
            Text(
                stringResource(R.string.write_a_note),
                color = MnTheme.buttonText,
                // iOS `.font(.headline)` = 17pt semibold.
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
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
