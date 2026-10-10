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
import com.mn.android.ui.streak.DayCellView
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
                        DayCellView(
                            date = today.minusDays(6L - index),
                            hasMeditation = flags.hasMeditation,
                            hasNote = flags.hasNote,
                            isToday = index == header.dayFlags.lastIndex,
                            // Every day this header shows is inside the 7-day
                            // window, so any partial day gets its dot.
                            showPartialIndicatorForRecentDays = true,
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