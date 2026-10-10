package com.mn.android.ui.meditate

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.mn.android.ui.theme.MnTheme
import kotlin.math.max

/**
 * Port of iOS `BreathingPathView`: the breathing pattern as a line — S-curve
 * (cubic) for inhale/exhale, flat line for holds — with a progress-colored
 * partial path and a ball on the current position.
 *
 * Same math as the Swift view: partial curves via de Casteljau split, so the
 * progress path and the ball always agree.
 */
@Composable
fun BreathingPathView(
    phases: List<BreathingSessionViewModel.Phase>,
    phaseIndex: Int,
    phaseProgress: Double,
    modifier: Modifier = Modifier,
) {
    val lineColor = MnTheme.textPrimary
    val progressColor = MnTheme.accentColor
    val ballColor = MnTheme.streakIndicator
    val heightDp = 280.dp

    Canvas(
        modifier
            .fillMaxWidth()
            .height(heightDp)
    ) {
        if (phases.isEmpty()) return@Canvas

        val heightPx = size.height
        val totalSeconds = max(phases.sumOf { it.durationSeconds }, 1.0)
        val widthPerSecond = size.width / totalSeconds.toFloat()

        data class Segment(val start: Offset, val end: Offset, val hold: Boolean)

        fun segments(): List<Segment> {
            val result = ArrayList<Segment>(phases.size)
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
                result.add(Segment(start, Offset(x, y), phase.type !in setOf("inhale", "exhale")))
            }
            return result
        }

        fun curveControls(segment: Segment): Triple<Offset, Offset, Offset> {
            // p0, control points (midX at each end's y), p3 — the iOS S-curve.
            val midX = (segment.start.x + segment.end.x) / 2f
            return Triple(
                Offset(midX, segment.start.y),
                Offset(midX, segment.end.y),
                segment.end,
            )
        }

        val segs = segments()
        if (segs.isEmpty()) return@Canvas

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

        // Ball — cubic point (or lerp on holds) of the current segment.
        val seg = segs[index]
        val t = phaseProgress.toFloat().coerceIn(0f, 1f)
        val ball = if (seg.hold) {
            Offset(seg.start.x + (seg.end.x - seg.start.x) * t, seg.start.y)
        } else {
            val (c1, c2, end) = curveControls(seg)
            val u = 1f - t
            val x = u * u * u * seg.start.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * end.x
            val y = u * u * u * seg.start.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * end.y
            Offset(x, y)
        }
        drawCircle(ballColor, radius = 20f, center = ball)
    }
}
