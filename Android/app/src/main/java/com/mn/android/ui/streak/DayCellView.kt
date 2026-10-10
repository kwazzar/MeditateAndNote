package com.mn.android.ui.streak

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Notes
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.R
import com.mn.android.ui.theme.MnTheme
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale

/** Cell states, mirroring the (hasMeditation, hasNote) switches in DayCellView. */
enum class DayCellState {
    COMPLETE, MEDITATION_ONLY, NOTE_ONLY, EMPTY;

    companion object {
        fun of(hasMeditation: Boolean, hasNote: Boolean): DayCellState = when {
            hasMeditation && hasNote -> COMPLETE
            hasMeditation -> MEDITATION_ONLY
            hasNote -> NOTE_ONLY
            else -> EMPTY
        }
    }
}

/**
 * Port of iOS `DayCellView`: one grid cell — "M" + note glyph tinted by
 * completion, a partial-state dot, and the weekday label underneath.
 *
 * [showPartialIndicatorForRecentDays] mirrors the iOS flag: today always shows
 * its partial dot, past partial days only when the flag is set (the home
 * header's 7-day grid leaves it false-free — every day it shows is recent —
 * while the month grid relies on the 7-day window).
 */
@Composable
fun DayCellView(
    date: LocalDate,
    hasMeditation: Boolean,
    hasNote: Boolean,
    isToday: Boolean,
    showPartialIndicatorForRecentDays: Boolean,
    modifier: Modifier = Modifier,
    onTap: (() -> Unit)? = null,
) {
    val state = DayCellState.of(hasMeditation, hasNote)
    val cellSize = 32.dp
    val weekdayLabel = remember(date) {
        DateTimeFormatter.ofPattern("EEE", Locale.US).format(date).take(2)
    }

    val background =
        if (state == DayCellState.COMPLETE) MnTheme.streakSuccess.copy(alpha = 0.15f)
        else MnTheme.cardBackground
    val borderColor =
        if (isToday) {
            if (state == DayCellState.COMPLETE) MnTheme.streakSuccess else MnTheme.streakActiveMeditation
        } else {
            if (state == DayCellState.COMPLETE) MnTheme.streakSuccess.copy(alpha = 0.5f) else MnTheme.divider
        }
    val isPartial = state == DayCellState.MEDITATION_ONLY || state == DayCellState.NOTE_ONLY
    val daysAgo = ChronoUnit.DAYS.between(date, LocalDate.now())
    val showPartialIndicator = isPartial &&
        (isToday || (showPartialIndicatorForRecentDays && daysAgo in 0..7))

    val description = stringResource(
        R.string.day_cell_description,
        weekdayLabel,
        stringResource(
            when (state) {
                DayCellState.COMPLETE -> R.string.day_cell_completed
                DayCellState.MEDITATION_ONLY -> R.string.day_cell_meditation_only
                DayCellState.NOTE_ONLY -> R.string.day_cell_note_only
                DayCellState.EMPTY -> R.string.day_cell_empty
            }
        ),
    )

    Column(
        modifier
            .semantics { contentDescription = description }
            .then(if (onTap != null) Modifier.clickable(onClick = onTap) else Modifier),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(
            Modifier
                .size(cellSize)
                .background(background, RoundedCornerShape(10.dp))
                .border(
                    if (isToday) 1.5.dp else 0.5.dp,
                    borderColor,
                    RoundedCornerShape(10.dp),
                )
        ) {
            Row(
                Modifier.align(Alignment.Center),
                horizontalArrangement = Arrangement.spacedBy(3.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "M",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (hasMeditation) MnTheme.streakActiveMeditation else MnTheme.streakMuted,
                )
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.Notes,
                    contentDescription = null,
                    tint = if (hasNote) MnTheme.streakActiveNote else MnTheme.streakMuted,
                    modifier = Modifier.size(12.dp),
                )
            }
            if (showPartialIndicator) {
                Box(
                    Modifier
                        .align(Alignment.TopEnd)
                        .size(6.dp)
                        .background(
                            if (state == DayCellState.MEDITATION_ONLY) MnTheme.streakIndicator
                            else MnTheme.streakActiveNote,
                            CircleShape,
                        )
                )
            }
        }
        Text(
            weekdayLabel,
            fontSize = 9.sp,
            fontWeight = FontWeight.Medium,
            color = MnTheme.textSecondary,
        )
    }
}
