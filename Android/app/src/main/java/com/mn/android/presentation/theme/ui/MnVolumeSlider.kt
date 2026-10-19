package com.mn.android.presentation.theme.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * iOS `Slider`: a 4 pt line with a round white knob.
 *
 * Material 3's stock slider is a 16 dp bar with a stop dot at the end and a
 * gap between the track and the knob — the iOS slider has neither, so the
 * `track` slot draws the line itself.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MnVolumeSlider(
    value: Float,
    onValueChange: (Float) -> Unit,
    modifier: Modifier = Modifier,
    knobSize: Dp = 20.dp,
) {
    // Theme colours are composable reads — take them here, the draw scope is
    // not composable.
    val trackColor = MnTheme.divider
    val fillColor = MnTheme.streakActiveMeditation
    val knobColor = MnTheme.buttonText
    Slider(
        value = value,
        onValueChange = onValueChange,
        valueRange = 0f..1f,
        modifier = modifier,
        thumb = {
            Box(
                Modifier
                    .size(knobSize)
                    .clip(CircleShape)
                    .background(knobColor),
            )
        },
        track = { state ->
            val fraction = ((state.value - state.valueRange.start) /
                (state.valueRange.endInclusive - state.valueRange.start)).coerceIn(0f, 1f)
            Canvas(
                Modifier
                    .fillMaxWidth()
                    .height(4.dp),
            ) {
                val mid = size.height / 2f
                drawLine(
                    color = trackColor,
                    start = Offset(0f, mid),
                    end = Offset(size.width, mid),
                    strokeWidth = size.height,
                    cap = StrokeCap.Round,
                )
                drawLine(
                    color = fillColor,
                    start = Offset(0f, mid),
                    end = Offset(size.width * fraction, mid),
                    strokeWidth = size.height,
                    cap = StrokeCap.Round,
                )
            }
        },
        // The track is drawn above; M3's own track stays invisible.
        colors = SliderDefaults.colors(
            thumbColor = Color.Transparent,
            activeTrackColor = Color.Transparent,
            inactiveTrackColor = Color.Transparent,
        ),
    )
}
