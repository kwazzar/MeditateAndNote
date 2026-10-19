package com.mn.android.presentation.meditate.ui

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.mn.android.presentation.theme.ui.MnTheme
import kotlin.math.max
import com.mn.android.presentation.meditate.viewmodel.BreathingSessionViewModel

/**
 * Port of iOS `BreathingPathView`: the breathing pattern as a line — S-curve
 * (cubic) for inhale/exhale, flat line for holds — with a progress-colored
 * partial path and a ball on the current position.
 *
 * Same math as the Swift view: partial curves via de Casteljau split, so the
 * progress path and the ball always agree.
 *
 * iOS animates the view with `.animation(.linear(duration: 0.1),
 * value: phaseProgress)`. The engine publishes `phaseProgress` every 100 ms, so
 * that modifier is what makes the ball glide instead of jumping 10 times a
 * second. SwiftUI can interpolate a `Circle`'s position, so only the ball
 * moves smoothly there — the path shape (a `Path`) snaps, exactly as here.
 */
@Composable
fun BreathingPathView(
    phases: List<BreathingSessionViewModel.Phase>,
    phaseIndex: Int,
    phaseProgress: Double,
    discriminator: String,
    modifier: Modifier = Modifier,
) {
    val lineColor = MnTheme.textPrimary
    val progressColor = MnTheme.accentColor
    // iOS passes `ballColor: breathingColor` — the phase colour, same as the
    // ring colour and the phase label.
    val ballColor = phaseColor(discriminator)
    val heightDp = 280.dp

    // The path geometry needs the canvas size, which is only known after
    // layout — the ball is animated outside the Canvas, so it needs it here.
    var canvasSize by remember { mutableStateOf(IntSize.Zero) }

    val segments = remember(phases, canvasSize) {
        buildSegments(phases, canvasSize.width.toFloat(), canvasSize.height.toFloat())
    }
    val target = remember(segments, phaseIndex, phaseProgress) {
        ballPosition(segments, phaseIndex, phaseProgress.toFloat().coerceIn(0f, 1f))
    }
    // iOS: `.animation(.linear(duration: 0.1), value: phaseProgress)`.
    // The ball's position is continuous across phase changes (the path is one
    // unbroken curve), so it never slides backwards.
    val ballX by animateFloatAsState(
        targetValue = target.x,
        animationSpec = tween(durationMillis = 100, easing = LinearEasing),
        label = "ballX",
    )
    val ballY by animateFloatAsState(
        targetValue = target.y,
        animationSpec = tween(durationMillis = 100, easing = LinearEasing),
        label = "ballY",
    )

    Canvas(
        modifier
            .fillMaxWidth()
            .height(heightDp)
            .onSizeChanged { canvasSize = it }
    ) {
        if (phases.isEmpty() || segments.isEmpty()) return@Canvas

        val segs = segments

        // Full static path — always visible, 35% line color.
        val full = Path().apply {
            moveTo(segs[0].start.x, segs[0].start.y)
            segs.forEach { seg ->
                if (seg.hold) {
                    lineTo(seg.end.x, seg.end.y)
                } else {
                    val (c1, c2, end) = curveControls(seg)
                    cubicTo(c1.x, c1.y, c2.x, c2.y, end.x, end.y)
                }
            }
        }
        drawPath(full, lineColor.copy(alpha = 0.35f), style = Stroke(width = 4f, cap = StrokeCap.Round))

        // Progress path: prior segments whole, current segment partial.
        val index = phaseIndex.coerceIn(0, segs.lastIndex)
        val partial = Path().apply {
            moveTo(segs[0].start.x, segs[0].start.y)
            for (i in 0 until index) {
                val seg = segs[i]
                if (seg.hold) lineTo(seg.end.x, seg.end.y)
                else {
                    val (c1, c2, end) = curveControls(seg)
                    cubicTo(c1.x, c1.y, c2.x, c2.y, end.x, end.y)
                }
            }
            val current = segs[index]
            val t = phaseProgress.toFloat().coerceIn(0f, 1f)
            if (current.hold) {
                val x = current.start.x + (current.end.x - current.start.x) * t
                lineTo(x, current.start.y)
            } else {
                val (c1, c2, end) = curveControls(current)
                // De Casteljau split at t: (p01, p012, p0123) — partial curve
                // controls + endpoint, matching the ball position exactly.
                fun lerp(a: Offset, b: Offset) = Offset(
                    a.x + (b.x - a.x) * t,
                    a.y + (b.y - a.y) * t,
                )
                val p01 = lerp(current.start, c1)
                val p12 = lerp(c1, c2)
                val p23 = lerp(c2, end)
                val p012 = lerp(p01, p12)
                val p123 = lerp(p12, p23)
                val p0123 = lerp(p012, p123)
                cubicTo(p01.x, p01.y, p012.x, p012.y, p0123.x, p0123.y)
            }
        }
        drawPath(partial, progressColor, style = Stroke(width = 4f, cap = StrokeCap.Round))

        // Ball — animated position (iOS animates the same way).
        drawCircle(ballColor, radius = 20f, center = Offset(ballX, ballY))
    }
}

private data class PathSegment(val start: Offset, val end: Offset, val hold: Boolean)

private fun buildSegments(
    phases: List<BreathingSessionViewModel.Phase>,
    widthPx: Float,
    heightPx: Float,
): List<PathSegment> {
    if (phases.isEmpty() || widthPx <= 0f || heightPx <= 0f) return emptyList()
    val result = ArrayList<PathSegment>(phases.size)
    val totalSeconds = max(phases.sumOf { it.durationSeconds }, 1.0)
    val widthPerSecond = widthPx / totalSeconds.toFloat()
    var x = 0f
    var y = heightPx
    for (phase in phases) {
        val start = Offset(x, y)
        x += (phase.durationSeconds * widthPerSecond).toFloat()
        y = when (phase.type) {
            "inhale" -> 0f
            "exhale" -> heightPx
            else -> y // holds stay flat
        }
        result.add(PathSegment(start, Offset(x, y), phase.type !in setOf("inhale", "exhale")))
    }
    return result
}

/** iOS S-curve: control points sit at the segment's mid-x, on each end's y. */
private fun curveControls(segment: PathSegment): Triple<Offset, Offset, Offset> {
    val midX = (segment.start.x + segment.end.x) / 2f
    return Triple(
        Offset(midX, segment.start.y),
        Offset(midX, segment.end.y),
        segment.end,
    )
}

/** Ball position on the current segment — cubic point (or lerp on holds). */
private fun ballPosition(segments: List<PathSegment>, index: Int, t: Float): Offset {
    if (segments.isEmpty()) return Offset.Zero
    val seg = segments[index.coerceIn(0, segments.lastIndex)]
    if (seg.hold) {
        return Offset(seg.start.x + (seg.end.x - seg.start.x) * t, seg.start.y)
    }
    val (c1, c2, end) = curveControls(seg)
    val u = 1f - t
    return Offset(
        u * u * u * seg.start.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * end.x,
        u * u * u * seg.start.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * end.y,
    )
}
