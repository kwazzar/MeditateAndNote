package com.mn.android.presentation.streak.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.data.StreakInsightsSource.Category
import com.mn.android.data.StreakInsightsSource.Heatmap
import com.mn.android.data.StreakInsightsSource.Insight
import com.mn.android.data.StreakInsightsSource.WeeklyBucket
import com.mn.android.presentation.theme.ui.MnTheme
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
    // iOS appear animation: columns scale up from the bottom, staggered.
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }
    Row {
        data.days.forEachIndexed { index, day ->
            val appear by animateFloatAsState(
                targetValue = if (appeared) 1f else 0f,
                animationSpec = tween(300, delayMillis = index * 50),
                label = "appear$index",
            )
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
                        .graphicsLayer(
                            scaleY = appear,
                            alpha = appear,
                            transformOrigin = TransformOrigin(0.5f, 1f),
                        )
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
