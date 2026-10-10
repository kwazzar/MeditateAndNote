package com.mn.android.ui.streak

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.NoteAdd
import androidx.compose.material.icons.automirrored.filled.Notes
import androidx.compose.material.icons.outlined.Balance
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.EmojiEvents
import androidx.compose.material.icons.outlined.Insights
import androidx.compose.material.icons.outlined.LocalFireDepartment
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Psychology
import androidx.compose.material.icons.outlined.Replay
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.data.StreakInsightsSource.Category
import com.mn.android.data.StreakInsightsSource.Heatmap
import com.mn.android.data.StreakInsightsSource.Insight
import com.mn.android.data.StreakInsightsSource.WeeklyBucket
import com.mn.android.ui.theme.MnTheme
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Port of iOS `WeekdayHeatmapView` (`WeekdayHeatmapView.swift`): seven
 * completion-rate columns with the weekday initial underneath.
 *
 * The one-shot appear animations (scale-up, staggered delays) are skipped —
 * the settled rendering is identical.
 */
@Composable
internal fun WeekdayHeatmapView(data: Heatmap) {
    Row {
        data.days.forEach { day ->
            Column(
                Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 2.dp)
                        .height(32.dp)
                        .background(rateColor(day.completionRate), RoundedCornerShape(4.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        "${(day.completionRate * 100).toInt()}",
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (day.completionRate > 0.4) MnTheme.buttonText else MnTheme.textSecondary,
                    )
                }
                Text(
                    day.shortName,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = MnTheme.textSecondary,
                )
            }
        }
    }
}

/** iOS `WeekdayHeatmapView.colorForRate` + `WeeklyBreakdownChart.barColor` — shared scale. */
@Composable
internal fun rateColor(rate: Double): Color = when {
    rate >= 0.75 -> MnTheme.streakSuccess
    rate >= 0.50 -> MnTheme.streakSuccess.copy(alpha = 0.6f)
    rate >= 0.25 -> MnTheme.streakIndicator
    rate > 0.0 -> MnTheme.danger.copy(alpha = 0.6f)
    else -> MnTheme.toolbarBackground
}

/** iOS `InsightCategory.label`. */
internal fun Category.label(): String = when (this) {
    Category.COMPLETION -> "Completion"
    Category.PATTERN -> "Pattern"
    Category.TREND -> "Trend"
    Category.RISK -> "Risk"
}

/** iOS `MainTheme`-served accent per category (`accentColor` switch). */
@Composable
internal fun Category.accent(): Color = when (this) {
    Category.RISK -> MnTheme.danger
    Category.TREND -> MnTheme.streakSuccess
    Category.PATTERN -> MnTheme.streakActiveNote
    Category.COMPLETION -> MnTheme.streakIndicator
}

/**
 * SF Symbol name → Material icon. The names are domain data from Core
 * (`StreakInsightEngine`), so the mapping table is exhaustive over what the
 * engine emits, with a generic fallback.
 */
internal fun insightIcon(sfName: String): ImageVector = when (sfName) {
    "arrow.counterclockwise" -> Icons.Outlined.Replay
    "bell.fill" -> Icons.Outlined.Notifications
    "brain.head.profile" -> Icons.Outlined.Psychology
    "calendar" -> Icons.Outlined.CalendarMonth
    "chart.bar.fill" -> Icons.Outlined.BarChart
    "clock.fill" -> Icons.Outlined.Schedule
    "exclamationmark.triangle.fill" -> Icons.Outlined.Warning
    "flame.fill" -> Icons.Outlined.LocalFireDepartment
    "note.text" -> Icons.AutoMirrored.Filled.Notes
    "note.text.badge.plus" -> Icons.AutoMirrored.Filled.NoteAdd
    "scalemass.fill" -> Icons.Outlined.Balance
    "trophy.fill" -> Icons.Outlined.EmojiEvents
    else -> Icons.Outlined.Insights
}

// MARK: - Insight drill-down (InsightDetailView)

/**
 * Port of iOS `InsightDetailView` — presented as a bottom sheet rather than a
 * pushed NavigationStack, matching how the day-detail sheet already renders.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
internal fun InsightDetailSheet(
    insight: Insight,
    range: String,
    weekly: List<WeeklyBucket>,
    onClose: () -> Unit,
) {
    ModalBottomSheet(
        onDismissRequest = onClose,
        containerColor = MnTheme.background,
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    insight.title,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 16.sp,
                    color = MnTheme.textPrimary,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    "Done",
                    color = MnTheme.streakIndicator,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier
                        .clickable(onClick = onClose)
                        .padding(start = 8.dp),
                )
            }

            // Header card
            MnCard {
                Row(
                    Modifier.padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Box(
                        Modifier
                            .size(44.dp)
                            .background(insight.category.accent().copy(alpha = 0.12f), CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            insightIcon(insight.icon),
                            contentDescription = null,
                            tint = insight.category.accent(),
                            modifier = Modifier.size(24.dp),
                        )
                    }
                    Column {
                        Text(
                            insight.title,
                            fontWeight = FontWeight.SemiBold,
                            color = MnTheme.textPrimary,
                        )
                        Text(
                            insight.category.label(),
                            fontSize = 12.sp,
                            color = MnTheme.textSecondary,
                        )
                    }
                }
            }

            insight.heatmap?.let { heatmap ->
                MnCard {
                    Column(
                        Modifier.padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Text(
                            "Completion by Day",
                            fontWeight = FontWeight.SemiBold,
                            color = MnTheme.textPrimary,
                        )
                        WeekdayHeatmapView(heatmap)
                        heatmap.days.minByOrNull { it.completionRate }?.let { weakest ->
                            if (weakest.completionRate < 0.5) {
                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Icon(
                                        Icons.Outlined.Warning,
                                        contentDescription = null,
                                        tint = MnTheme.streakIndicator,
                                        modifier = Modifier.size(12.dp),
                                    )
                                    Text(
                                        "Focus on ${weakest.name}s — your weakest day",
                                        fontSize = 12.sp,
                                        color = MnTheme.textSecondary,
                                    )
                                }
                            }
                        }
                    }
                }
            }

            if (weekly.isNotEmpty()) {
                MnCard {
                    Column(
                        Modifier.padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                "Weekly Completion",
                                fontWeight = FontWeight.SemiBold,
                                color = MnTheme.textPrimary,
                                modifier = Modifier.weight(1f),
                            )
                            Text(
                                rangeShortLabel(range),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MnTheme.streakActiveMeditation,
                                modifier = Modifier
                                    .background(
                                        MnTheme.streakActiveMeditation.copy(alpha = 0.18f),
                                        RoundedCornerShape(50),
                                    )
                                    .padding(horizontal = 8.dp, vertical = 3.dp),
                            )
                        }
                        WeeklyBreakdownChart(buckets = weekly, range = range)
                        weekly.maxByOrNull { it.completionRate }?.let { best ->
                            if (best.completionRate > 0) {
                                Text(
                                    "Best week: ${formatWeek(best.weekStartMillis)} — ${(best.completionRate * 100).toInt()}% complete",
                                    fontSize = 12.sp,
                                    color = MnTheme.textSecondary,
                                )
                            }
                        }
                    }
                }
            }

            insight.value?.let { value ->
                MnCard {
                    Column(
                        Modifier.padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Row {
                            Text(
                                "Progress",
                                fontWeight = FontWeight.SemiBold,
                                color = MnTheme.textPrimary,
                                modifier = Modifier.weight(1f),
                            )
                            Text(
                                "${(value * 100).toInt()}%",
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Bold,
                                color = insight.category.accent(),
                            )
                        }
                        Box(
                            Modifier
                                .fillMaxWidth()
                                .height(8.dp)
                                .background(MnTheme.toolbarBackground, RoundedCornerShape(50)),
                        ) {
                            Box(
                                Modifier
                                    .fillMaxWidth(value.coerceIn(0.0, 1.0).toFloat())
                                    .height(8.dp)
                                    .background(insight.category.accent(), RoundedCornerShape(50)),
                            )
                        }
                    }
                }
            }

            MnCard {
                Text(
                    insight.message,
                    color = MnTheme.textPrimary,
                    modifier = Modifier.padding(14.dp),
                )
            }
        }
    }
}

/** iOS `InsightDetailView.formatWeek` — "MMM d". */
private fun formatWeek(millis: Long): String =
    Instant.ofEpochMilli(millis)
        .atZone(ZoneId.systemDefault())
        .format(DateTimeFormatter.ofPattern("MMM d", Locale.US))

/** iOS `StreakRange.shortLabel`. */
internal fun rangeShortLabel(range: String): String = when (range) {
    "last7" -> "7D"
    "last30" -> "30D"
    else -> "90D"
}

/** iOS `StreakRange.title`. */
internal fun rangeTitle(range: String): String = when (range) {
    "last7" -> "Last 7 Days"
    "last30" -> "Last 30 Days"
    else -> "Last 90 Days"
}

// MARK: - Weekly breakdown chart (drill-down bars)

/** Port of iOS `WeeklyBreakdownChart`: bottom-anchored bars, 96 pt tall. */
@Composable
private fun WeeklyBreakdownChart(buckets: List<WeeklyBucket>, range: String) {
    val spacing = (48 / buckets.count().coerceAtLeast(1)).coerceIn(2, 8)
    Row(
        Modifier
            .fillMaxWidth()
            .height(96.dp),
        horizontalArrangement = Arrangement.spacedBy(spacing.dp),
    ) {
        buckets.forEach { bucket ->
            val rate = bucket.completionRate.coerceIn(0.0, 1.0)
            Column(
                Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Box(Modifier.weight(1f), contentAlignment = Alignment.BottomCenter) {
                    Box(
                        Modifier
                            .fillMaxWidth(0.7f)
                            .height((96 * rate).dp.coerceAtLeast(4.dp))
                            .background(rateColor(rate), RoundedCornerShape(4.dp)),
                    )
                }
                Text(
                    if (range == "last7") "" else weekLabel(bucket.weekStartMillis),
                    fontSize = 8.sp,
                    fontWeight = FontWeight.Medium,
                    color = MnTheme.textSecondary,
                )
            }
        }
    }
}

private fun weekLabel(millis: Long): String =
    Instant.ofEpochMilli(millis)
        .atZone(ZoneId.systemDefault())
        .dayOfMonth.toString()
