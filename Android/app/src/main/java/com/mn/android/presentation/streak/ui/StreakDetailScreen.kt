package com.mn.android.presentation.streak.ui

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
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.Notes
import androidx.compose.material.icons.filled.CheckCircle



import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue

import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember

import androidx.compose.ui.Alignment
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.foundation.border
import androidx.compose.ui.draw.clip
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
import com.mn.android.data.StreakInsightsSource
import com.mn.android.presentation.theme.ui.MnBackground
import com.mn.android.presentation.theme.ui.MnTheme

import java.time.LocalDate




/**
 * Port of iOS `StreakDetailView`: stats header, today progress, insights +
 * lifetime patterns (from `StreakInsightsSource`, the JNI read over
 * `StreakInsightManager`), and the current-month calendar with its day-detail
 * sheet.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StreakDetailScreen(
    onBack: () -> Unit,
    onStartMeditation: () -> Unit,
    onWriteNote: () -> Unit,
) {
    var detail by remember { mutableStateOf(StreakDetailSource.readDetail()) }
    // Insights range + bundle: one JNI read shared by InsightsSection and
    // LifetimePatternsSection (the lifetime cards are range-independent).
    var range by remember { mutableStateOf("last7") }
    var insights by remember { mutableStateOf(StreakInsightsSource.load(range)) }
    LaunchedEffect(range) {
        insights = StreakInsightsSource.load(range)
    }
    // The sheet's CTA navigates away, and today's flags change when the user
    // comes back from that flow — reload on resume until DomainEventBus lands
    // (same fallback as NoteMenuScreen).
    LifecycleResumeEffect(Unit) {
        detail = StreakDetailSource.readDetail()
        insights = StreakInsightsSource.load(range)
        onPauseOrDispose { }
    }
    var selected by remember { mutableStateOf<StreakDetailSource.Day?>(null) }

    Box(Modifier.fillMaxSize()) {
        MnBackground()
        Scaffold(
            topBar = {
            // iOS StreakDetailView: centred title, bordered "Done" pill.
            CenterAlignedTopAppBar(
                title = { Text(stringResource(R.string.streak), fontWeight = FontWeight.Bold) },
                actions = {
                    Box(
                        Modifier
                            .padding(end = 12.dp)
                            .clip(CircleShape)
                            .border(1.dp, MnTheme.divider, CircleShape)
                            .clickable(onClick = onBack)
                            .padding(horizontal = 20.dp, vertical = 8.dp),
                    ) {
                        Text(
                            stringResource(R.string.done),
                            color = MnTheme.textPrimary,
                            style = MaterialTheme.typography.titleMedium,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                    titleContentColor = MnTheme.textPrimary,
                ),
            )
        },
        containerColor = Color.Transparent,
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
            InsightsSection(
                bundle = insights,
                range = range,
                onRangeChange = { range = it },
                onNavigateToMeditation = onStartMeditation,
                onNavigateToNote = onWriteNote,
            )
            LifetimePatternsSection(insights)
            MonthGrid(
                title = StreakDetailSource.monthTitle(),
                weeks = detail.weeks,
                onSelect = { day -> selected = day },
            )
            Spacer(Modifier.height(24.dp))
        }
        }
    }

    selected?.let { day ->
        ModalBottomSheet(
            onDismissRequest = { selected = null },
            containerColor = MnTheme.background,
            dragHandle = null,
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

/** Shared card surface — `.ultraThinMaterial` on iOS, `cardBackground` here. */
@Composable
internal fun MnCard(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
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
            stringResource(R.string.number_format, value),
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

