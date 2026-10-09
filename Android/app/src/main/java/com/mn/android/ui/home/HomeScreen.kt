package com.mn.android.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.Notes
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Whatshot
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.R
import com.mn.android.data.StreakHeaderSource
import com.mn.android.data.StreakHeaderSource.DayFlags
import com.mn.android.ui.theme.MnTheme
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Port of the iOS MainView home tab: StreakHeaderView (streak count + the
 * last-7-days grid), the note-reminder banner, the Meditate entry point and
 * the Settings button.
 *
 * Data comes from the Swift snapshot through [StreakHeaderSource]; the JSON
 * itself is never parsed in Kotlin.
 */
@Composable
fun HomeScreen(
    onMeditate: () -> Unit,
    onStreakDetail: () -> Unit,
    onSettings: () -> Unit,
    onNewNote: () -> Unit,
) {
    Box(
        Modifier
            .fillMaxSize()
            .background(MnTheme.background)
    ) {
        val header = remember { StreakHeaderSource.readHeader() }
        Column(
            Modifier
                .fillMaxSize()
                .padding(top = 8.dp)
        ) {
            StreakHeaderCard(
                header = header,
                onStreakDetail = onStreakDetail,
                onNewNote = onNewNote,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
            Spacer(Modifier.weight(1f))
        }

        Button(
            onClick = onMeditate,
            modifier = Modifier
                .align(Alignment.Center)
                .fillMaxWidth()
                .padding(horizontal = 48.dp, vertical = 24.dp),
            colors = ButtonDefaults.buttonColors(containerColor = MnTheme.accentButton),
        ) {
            Text(
                stringResource(R.string.meditate),
                color = MnTheme.buttonText,
                fontWeight = FontWeight.SemiBold,
            )
        }

        SettingsButton(
            onClick = onSettings,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(bottom = 80.dp, end = 26.dp),
        )
    }
}

// MARK: - Streak header

@Composable
private fun StreakHeaderCard(
    header: StreakHeaderSource.Header,
    onStreakDetail: () -> Unit,
    onNewNote: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Surface(
            onClick = onStreakDetail,
            shape = RoundedCornerShape(14.dp),
            color = MnTheme.cardBackground,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Row(
                Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                StreakNumberSection(
                    currentStreak = header.currentStreak,
                    isTodayComplete = header.isTodayComplete,
                )
                Box(
                    Modifier
                        .width(0.5.dp)
                        .height(44.dp)
                        .background(MnTheme.divider)
                )
                Row(Modifier.padding(start = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                    val today = LocalDate.now()
                    header.dayFlags.forEachIndexed { index, flags ->
                        DayCell(
                            flags = flags,
                            date = today.minusDays(6L - index),
                            isToday = index == header.dayFlags.lastIndex,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
        }

        if (header.showNoteReminder) {
            NoteReminderBanner(onNewNote)
        }
    }
}

@Composable
private fun StreakNumberSection(currentStreak: Int, isTodayComplete: Boolean) {
    Column(
        Modifier
            .width(72.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Row(verticalAlignment = Alignment.Bottom) {
            Icon(
                imageVector = Icons.Filled.Whatshot,
                contentDescription = null,
                tint = if (isTodayComplete) MnTheme.streakSuccess else MnTheme.textSecondary,
                modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.width(4.dp))
            Text(
                "$currentStreak",
                fontSize = 22.sp,
                fontWeight = FontWeight.Medium,
                color = MnTheme.textPrimary,
            )
        }
        Text(
            pluralStringResource(R.plurals.streak_days, currentStreak),
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
            color = MnTheme.textSecondary,
        )
    }
}

// MARK: - Day cells (DayCellView)

/** Cell states, mirroring the (hasMeditation, hasNote) switches in DayCellView. */
private enum class DayCellState {
    COMPLETE, MEDITATION_ONLY, NOTE_ONLY, EMPTY;

    companion object {
        fun of(flags: DayFlags): DayCellState = when {
            flags.hasMeditation && flags.hasNote -> COMPLETE
            flags.hasMeditation -> MEDITATION_ONLY
            flags.hasNote -> NOTE_ONLY
            else -> EMPTY
        }
    }
}

@Composable
private fun DayCell(flags: DayFlags, date: LocalDate, isToday: Boolean, modifier: Modifier = Modifier) {
    val state = DayCellState.of(flags)
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
    // With showPartialIndicatorForRecentDays=true every shown day is within the
    // 7-day window, so any partial day gets the dot — including today.
    val showPartialIndicator = state == DayCellState.MEDITATION_ONLY || state == DayCellState.NOTE_ONLY

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
        modifier.semantics { contentDescription = description },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(
            Modifier
                .size(cellSize)
                .background(background, RoundedCornerShape(10.dp))
                .border(0.5.dp, borderColor, RoundedCornerShape(10.dp))
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
                    color = if (flags.hasMeditation) MnTheme.streakActiveMeditation else MnTheme.streakMuted,
                )
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.Notes,
                    contentDescription = null,
                    tint = if (flags.hasNote) MnTheme.streakActiveNote else MnTheme.streakMuted,
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

// MARK: - Note reminder banner

@Composable
private fun NoteReminderBanner(onNewNote: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(MnTheme.streakIndicator.copy(alpha = 0.1f), RoundedCornerShape(10.dp))
            .clickable(onClick = onNewNote)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = Icons.Filled.Edit,
            contentDescription = null,
            tint = MnTheme.streakIndicator,
            modifier = Modifier.size(14.dp),
        )
        Text(
            stringResource(R.string.streak_note_reminder),
            color = MnTheme.streakIndicator,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Medium,
            modifier = Modifier
                .weight(1f)
                .padding(start = 8.dp),
        )
        Icon(
            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = MnTheme.streakIndicator,
            modifier = Modifier.size(16.dp),
        )
    }
}

// MARK: - Settings

@Composable
private fun SettingsButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier
            .height(40.dp)
            .alpha(0.9f)
            .background(MnTheme.cardBackground, CircleShape)
            .border(1.dp, MnTheme.divider, CircleShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 15.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = Icons.Filled.Settings,
            contentDescription = null,
            tint = MnTheme.textPrimary,
            modifier = Modifier.size(18.dp),
        )
        Text(
            stringResource(R.string.settings),
            color = MnTheme.textPrimary,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(start = 6.dp),
        )
    }
}

// MARK: - Previews

@Preview(name = "Streak card, reminder shown")
@Composable
private fun StreakHeaderCardPreview() {
    val header = StreakHeaderSource.Header(
        currentStreak = 4,
        dayFlags = listOf(
            DayFlags(true, true),  // Mo
            DayFlags(true, false), // Tu — meditation only, dot
            DayFlags(false, true), // We — note only, dot
            DayFlags(false, false),
            DayFlags(true, true),
            DayFlags(false, false),
            DayFlags(true, false), // today — reminder shown
        ),
    )
    Box(Modifier.background(MnTheme.background)) {
        Column(Modifier.padding(16.dp)) {
            StreakHeaderCard(header = header, onStreakDetail = {}, onNewNote = {})
        }
    }
}