package com.mn.android.ui.streak

import androidx.compose.foundation.background
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.Notes
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.SelfImprovement
import androidx.compose.material.icons.filled.Whatshot
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.mn.android.R
import com.mn.android.data.StreakDetailSource
import com.mn.android.ui.theme.MnTheme
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Port of iOS `StreakDetailView`: stats header, today progress, and the
 * current-month calendar with its day-detail sheet.
 *
 * The iOS screen's `InsightsSection` and `LifetimePatternsSection` are NOT
 * ported — they read `StreakInsightManager`, which has no Android/JNI
 * implementation yet (ANDROID_PORT_PLAN.md section 2.x). Nothing stands in
 * for them here.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StreakDetailScreen(
    onBack: () -> Unit,
    onStartMeditation: () -> Unit,
    onWriteNote: () -> Unit,
) {
    var detail by remember { mutableStateOf(StreakDetailSource.readDetail()) }
    // The sheet's CTA navigates away, and today's flags change when the user
    // comes back from that flow — reload on resume until DomainEventBus lands
    // (same fallback as NoteMenuScreen).
    LifecycleResumeEffect(Unit) {
        detail = StreakDetailSource.readDetail()
        onPauseOrDispose { }
    }
    var selected by remember { mutableStateOf<StreakDetailSource.Day?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.streak)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.back),
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                    titleContentColor = MnTheme.textPrimary,
                    navigationIconContentColor = MnTheme.textPrimary,
                ),
            )
        },
        containerColor = MnTheme.background,
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            StatsHeader(
                current = detail.currentStreak,
                best = detail.longestStreak,
                total = detail.totalCompleteDays,
            )
            TodayProgress(
                today = detail.today,
                onStartMeditation = onStartMeditation,
                onWriteNote = onWriteNote,
            )
            MonthGrid(
                title = StreakDetailSource.monthTitle(),
                weeks = detail.weeks,
                onSelect = { day -> selected = day },
            )
            Spacer(Modifier.height(24.dp))
        }
    }

    selected?.let { day ->
        ModalBottomSheet(
            onDismissRequest = { selected = null },
            containerColor = MnTheme.background,
        ) {
            StreakDayDetailSheet(
                day = day,
                onClose = { selected = null },
                onMissingAction = { action ->
                    selected = null
                    when (action) {
                        DayDetailAction.MEDITATION -> onStartMeditation()
                        DayDetailAction.NOTE -> onWriteNote()
                    }
                },
            )
        }
    }
}

@Composable
private fun MnCard(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Box(
        Modifier
            .fillMaxWidth()
            .then(modifier)
            .background(MnTheme.cardBackground, RoundedCornerShape(14.dp)),
    ) { content() }
}

// MARK: - Stats header

@Composable
private fun StatsHeader(current: Int, best: Int, total: Int) {
    MnCard {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            StatColumn(stringResource(R.string.current), current, accent = true)
            StatDivider()
            StatColumn(stringResource(R.string.best), best, accent = false)
            StatDivider()
            StatColumn(stringResource(R.string.total), total, accent = false)
        }
    }
}

@Composable
private fun StatColumn(title: String, value: Int, accent: Boolean) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            "$value",
            fontSize = 22.sp,
            fontWeight = FontWeight.Medium,
            color = if (accent) MnTheme.streakIndicator else MnTheme.textPrimary,
        )
        Text(title, fontSize = 12.sp, color = MnTheme.textSecondary)
    }
}

@Composable
private fun StatDivider() {
    Box(
        Modifier
            .width(0.5.dp)
            .height(40.dp)
            .background(MnTheme.divider),
    )
}

// MARK: - Today progress

private enum class PillGlyph { MEDITATION, NOTE }

@Composable
private fun TodayProgress(
    today: StreakDetailSource.Day?,
    onStartMeditation: () -> Unit,
    onWriteNote: () -> Unit,
) {
    val hasMeditation = today?.hasMeditation == true
    val hasNote = today?.hasNote == true
    val state = DayCellState.of(hasMeditation, hasNote)

    MnCard {
        Column(
            Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                stringResource(R.string.today),
                fontWeight = FontWeight.SemiBold,
                color = MnTheme.textPrimary,
                fontSize = 14.sp,
            )
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                ProgressPill(
                    glyph = PillGlyph.MEDITATION,
                    label = stringResource(R.string.meditation),
                    isDone = hasMeditation,
                    activeColor = MnTheme.streakActiveMeditation,
                    onTap = if (state == DayCellState.NOTE_ONLY) onStartMeditation else null,
                )
                ProgressPill(
                    glyph = PillGlyph.NOTE,
                    label = stringResource(R.string.note),
                    isDone = hasNote,
                    activeColor = MnTheme.streakActiveNote,
                    onTap = if (state == DayCellState.MEDITATION_ONLY) onWriteNote else null,
                )
                Spacer(Modifier.weight(1f))
                if (state == DayCellState.COMPLETE) {
                    Icon(
                        imageVector = Icons.Filled.CheckCircle,
                        contentDescription = null,
                        tint = MnTheme.streakSuccess,
                        modifier = Modifier.size(20.dp),
                    )
                }
            }
            val hint = when (state) {
                DayCellState.MEDITATION_ONLY -> stringResource(R.string.hint_meditation_only)
                DayCellState.NOTE_ONLY -> stringResource(R.string.hint_note_only)
                else -> null
            }
            if (hint != null) {
                Text(hint, fontSize = 12.sp, color = MnTheme.textSecondary)
            }
        }
    }
}

@Composable
private fun ProgressPill(
    glyph: PillGlyph,
    label: String,
    isDone: Boolean,
    activeColor: Color,
    onTap: (() -> Unit)?,
) {
    val tint = if (isDone) activeColor else MnTheme.streakMuted
    Row(
        Modifier
            .background(
                if (isDone) activeColor.copy(alpha = 0.12f) else MnTheme.cardBackground,
                CircleShape,
            )
            .then(if (onTap != null) Modifier.clickable(onClick = onTap) else Modifier)
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        when (glyph) {
            PillGlyph.MEDITATION -> Text(
                "M",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = tint,
            )
            PillGlyph.NOTE -> Icon(
                imageVector = Icons.AutoMirrored.Filled.Notes,
                contentDescription = null,
                tint = tint,
                modifier = Modifier.size(13.dp),
            )
        }
        Icon(
            imageVector = if (isDone) Icons.Filled.CheckCircle else Icons.Outlined.Circle,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(12.dp),
        )
        Text(label, fontSize = 12.sp, color = MnTheme.textPrimary)
        if (onTap != null && !isDone) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MnTheme.textSecondary,
                modifier = Modifier.size(12.dp),
            )
        }
    }
}

// MARK: - Calendar grid

/** iOS `veryShortWeekdaySymbols` for the en_US calendar it hardcodes: Sunday first. */
private val WeekdaySymbols = listOf("S", "M", "T", "W", "T", "F", "S")

@Composable
private fun MonthGrid(
    title: String,
    weeks: List<List<StreakDetailSource.Day?>>,
    onSelect: (StreakDetailSource.Day) -> Unit,
) {
    MnCard {
        Column(
            Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                title,
                fontWeight = FontWeight.SemiBold,
                color = MnTheme.textPrimary,
                fontSize = 14.sp,
            )
            Row(Modifier.fillMaxWidth()) {
                WeekdaySymbols.forEach { symbol ->
                    Text(
                        symbol,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium,
                        color = MnTheme.textSecondary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
            weeks.forEach { week ->
                Row(Modifier.fillMaxWidth()) {
                    week.forEach { day ->
                        if (day == null) {
                            Spacer(Modifier.weight(1f))
                        } else {
                            DayCellView(
                                date = day.date,
                                hasMeditation = day.hasMeditation,
                                hasNote = day.hasNote,
                                isToday = day.date == LocalDate.now(),
                                showPartialIndicatorForRecentDays = true,
                                modifier = Modifier.weight(1f),
                                onTap = { onSelect(day) },
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Day detail sheet (StreakDayDetailSheet)

private enum class DayDetailAction { MEDITATION, NOTE }

@Composable
private fun StreakDayDetailSheet(
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
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                if (day.date == LocalDate.now()) "Today"
                else day.date.format(DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.US)),
                fontWeight = FontWeight.SemiBold,
                fontSize = 16.sp,
                color = MnTheme.textPrimary,
                modifier = Modifier.weight(1f),
            )
            Text(
                stringResource(R.string.done),
                color = MnTheme.streakIndicator,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.clickable(onClick = onClose),
            )
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
                            DayCellState.EMPTY -> Icons.Filled.Whatshot
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
