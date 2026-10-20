package com.mn.android.presentation.streak.ui

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
import androidx.compose.material.icons.outlined.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.data.StreakInsightsSource.Insight
import com.mn.android.data.StreakInsightsSource.WeeklyBucket
import com.mn.android.presentation.theme.ui.MnDoneButton
import com.mn.android.presentation.theme.ui.MnTheme
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import androidx.compose.ui.res.stringResource
import com.mn.android.R

/** iOS `InsightDetailView` drill-down sheet: header, heatmap, weekly bars,
 *  progress, message. Presented as a bottom sheet (like StreakDayDetailSheet). */

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
                MnDoneButton(onClick = onClose, modifier = Modifier.padding(start = 8.dp))
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
                            stringResource(R.string.completion_by_day),
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
                                stringResource(R.string.weekly_completion),
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
                                stringResource(R.string.progress),
                                fontWeight = FontWeight.SemiBold,
                                color = MnTheme.textPrimary,
                                modifier = Modifier.weight(1f),
                            )
                            Text(
                                stringResource(R.string.percent_format, (value * 100).toInt()),
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
