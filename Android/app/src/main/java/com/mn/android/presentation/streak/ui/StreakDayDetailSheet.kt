package com.mn.android.presentation.streak.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.Notes
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.SelfImprovement
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.R
import com.mn.android.data.StreakDetailSource
import com.mn.android.presentation.theme.ui.MnTheme
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** iOS `StreakDayDetail`: one day's status, times, and the missing-half CTA. */

internal enum class DayDetailAction { MEDITATION, NOTE }

@Composable
internal fun StreakDayDetailSheet(
    day: StreakDetailSource.Day,
    onClose: () -> Unit,
    onMissingAction: (DayDetailAction) -> Unit,
) {
    val state = DayCellState.of(day.hasMeditation, day.hasNote)
    val accent = when (state) {
        DayCellState.COMPLETE -> MnTheme.streakSuccess
        DayCellState.MEDITATION_ONLY -> MnTheme.streakIndicator
        DayCellState.NOTE_ONLY -> MnTheme.streakActiveNote
        DayCellState.EMPTY -> MnTheme.textSecondary
    }
    // Mirrors StreakDayDetail.missingAction: the missing half of a partial day.
    val missingAction = when (state) {
        DayCellState.MEDITATION_ONLY -> DayDetailAction.NOTE
        DayCellState.NOTE_ONLY -> DayDetailAction.MEDITATION
        else -> null
    }

    Column(
        Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // iOS nav bar: centred title with a bordered "Done" pill trailing.
        Box(Modifier.fillMaxWidth()) {
            Text(
                if (day.date == LocalDate.now()) "Today"
                else day.date.format(DateTimeFormatter.ofPattern("d MMM yyyy", Locale.US)),
                fontWeight = FontWeight.Bold,
                fontSize = 17.sp,
                color = MnTheme.textPrimary,
                modifier = Modifier.align(Alignment.Center),
            )
            Box(
                Modifier
                    .align(Alignment.CenterEnd)
                    .clip(CircleShape)
                    .border(1.dp, MnTheme.divider, CircleShape)
                    .clickable(onClick = onClose)
                    .padding(horizontal = 18.dp, vertical = 7.dp),
            ) {
                Text(
                    stringResource(R.string.done),
                    color = MnTheme.textPrimary,
                    fontSize = 15.sp,
                )
            }
        }

        MnCard {
            Row(
                Modifier.padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(
                    Modifier
                        .size(44.dp)
                        .background(accent.copy(alpha = 0.12f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = when (state) {
                            DayCellState.COMPLETE -> Icons.Filled.CheckCircle
                            DayCellState.MEDITATION_ONLY -> Icons.Filled.SelfImprovement
                            DayCellState.NOTE_ONLY -> Icons.AutoMirrored.Filled.Notes
                            DayCellState.EMPTY -> Icons.Filled.DarkMode
                        },
                        contentDescription = null,
                        tint = accent,
                    )
                }
                Column {
                    Text(
                        stringResource(
                            when (state) {
                                DayCellState.COMPLETE -> R.string.core_day_complete
                                DayCellState.MEDITATION_ONLY -> R.string.meditation_only_title
                                DayCellState.NOTE_ONLY -> R.string.note_only_title
                                DayCellState.EMPTY -> R.string.no_activity
                            }
                        ),
                        fontWeight = FontWeight.SemiBold,
                        color = MnTheme.textPrimary,
                    )
                    Text(
                        stringResource(
                            when (state) {
                                DayCellState.COMPLETE -> R.string.core_day_complete_sub
                                DayCellState.MEDITATION_ONLY -> R.string.meditation_only_sub
                                DayCellState.NOTE_ONLY -> R.string.note_only_sub
                                DayCellState.EMPTY -> R.string.no_activity_sub
                            }
                        ),
                        fontSize = 12.sp,
                        color = MnTheme.textSecondary,
                    )
                }
            }
        }

        MnCard {
            Column(
                Modifier.padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                StateRow(
                    glyph = "M",
                    label = stringResource(R.string.meditation),
                    isDone = state == DayCellState.COMPLETE || state == DayCellState.MEDITATION_ONLY,
                    color = MnTheme.streakActiveMeditation,
                )
                StateRow(
                    glyph = null,
                    label = stringResource(R.string.note),
                    isDone = state == DayCellState.COMPLETE || state == DayCellState.NOTE_ONLY,
                    color = MnTheme.streakActiveNote,
                )
            }
        }

        if (day.meditationTime != null || day.noteTime != null) {
            MnCard {
                Column(
                    Modifier.padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        stringResource(R.string.when_section),
                        fontWeight = FontWeight.SemiBold,
                        color = MnTheme.textPrimary,
                    )
                    day.meditationTime?.let { millis ->
                        TimeRow(
                            label = stringResource(R.string.meditation),
                            time = formatTimeOfDay(millis),
                            color = MnTheme.streakActiveMeditation,
                        )
                    }
                    day.noteTime?.let { millis ->
                        TimeRow(
                            label = stringResource(R.string.note),
                            time = formatTimeOfDay(millis),
                            color = MnTheme.streakActiveNote,
                        )
                    }
                }
            }
        }

        if (missingAction != null) {
            val isMeditation = missingAction == DayDetailAction.MEDITATION
            MnCard {
                Column(
                    Modifier.padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        stringResource(
                            if (isMeditation) R.string.complete_day_meditation
                            else R.string.complete_day_note
                        ),
                        fontWeight = FontWeight.SemiBold,
                        color = MnTheme.textPrimary,
                    )
                    Text(
                        stringResource(
                            if (isMeditation) R.string.missing_meditation_half
                            else R.string.missing_note_half
                        ),
                        fontSize = 12.sp,
                        color = MnTheme.textSecondary,
                    )
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .background(accent.copy(alpha = 0.15f), RoundedCornerShape(12.dp))
                            .clickable { onMissingAction(missingAction) }
                            .padding(horizontal = 14.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Icon(
                            imageVector = if (isMeditation) Icons.Filled.SelfImprovement
                            else Icons.AutoMirrored.Filled.Notes,
                            contentDescription = null,
                            tint = accent,
                            modifier = Modifier.size(14.dp),
                        )
                        Text(
                            stringResource(
                                if (isMeditation) R.string.start_meditation
                                else R.string.write_note
                            ),
                            color = accent,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 14.sp,
                        )
                        Spacer(Modifier.weight(1f))
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                            contentDescription = null,
                            tint = accent,
                            modifier = Modifier.size(14.dp),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun StateRow(glyph: String?, label: String, isDone: Boolean, color: Color) {
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(Modifier.width(22.dp), contentAlignment = Alignment.CenterStart) {
            if (glyph != null) {
                Text(
                    glyph,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = if (isDone) color else MnTheme.streakMuted,
                )
            } else {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.Notes,
                    contentDescription = null,
                    tint = if (isDone) color else MnTheme.streakMuted,
                    modifier = Modifier.size(14.dp),
                )
            }
        }
        Text(label, color = MnTheme.textPrimary, fontWeight = FontWeight.Medium)
        Spacer(Modifier.weight(1f))
        Icon(
            imageVector = if (isDone) Icons.Filled.CheckCircle else Icons.Outlined.Circle,
            contentDescription = null,
            tint = if (isDone) color else MnTheme.streakMuted,
            modifier = Modifier.size(14.dp),
        )
    }
}

@Composable
private fun TimeRow(label: String, time: String, color: Color) {
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Schedule,
            contentDescription = null,
            tint = color,
            modifier = Modifier.size(12.dp),
        )
        Text(label, color = MnTheme.textPrimary, fontWeight = FontWeight.Medium)
        Spacer(Modifier.weight(1f))
        Text(time, fontSize = 12.sp, color = MnTheme.textSecondary)
    }
}

private fun formatTimeOfDay(millis: Long): String =
    Instant.ofEpochMilli(millis)
        .atZone(ZoneId.systemDefault())
        .format(DateTimeFormatter.ofPattern("h:mm a", Locale.US))
