package com.mn.android.presentation.streak.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.R
import com.mn.android.data.SharedPrefsReminderSettingsStore
import com.mn.android.data.StreakInsightsSource.Bundle
import com.mn.android.data.StreakInsightsSource.Insight
import com.mn.android.data.StreakInsightsSource.Recommendation
import com.mn.android.data.StreakInsightsSource.RecommendationAction
import com.mn.android.presentation.theme.ui.MnTheme
import androidx.compose.ui.res.stringResource

/**
 * Port of iOS `InsightsSection`: recommendations block, insights header with
 * the 7D/30D/90D range picker, and the insight cards (plain + heatmap row).
 *
 * The range itself and the bundle are owned by the parent
 * (StreakDetailScreen) so `LifetimePatternsSection` can share one JNI read —
 * lifetime cards are range-independent by design.
 */
@Composable
internal fun InsightsSection(
    bundle: Bundle,
    range: String,
    onRangeChange: (String) -> Unit,
    onNavigateToMeditation: () -> Unit,
    onNavigateToNote: () -> Unit,
) {
    var selectedInsight by remember { mutableStateOf<Insight?>(null) }
    var reminderMessage by remember { mutableStateOf<String?>(null) }

    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        if (bundle.recommendations.isNotEmpty()) {
            RecommendationsBlock(
                recommendations = bundle.recommendations,
                onAction = { action ->
                    when (action) {
                        RecommendationAction.NAVIGATE_TO_MEDITATION -> onNavigateToMeditation()
                        RecommendationAction.NAVIGATE_TO_NOTE -> onNavigateToNote()
                        RecommendationAction.SET_REMINDER -> enableReminderForWeakestDay(
                            bundle = bundle,
                            onMessage = { reminderMessage = it },
                        )
                        null -> {}
                    }
                },
            )
        }

        InsightsHeader(bundle = bundle, range = range, onRangeChange = onRangeChange)

        if (bundle.insights.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                bundle.insights.forEach { insight ->
                    if (insight.heatmap != null) {
                        HeatmapInsightRow(insight, onClick = { selectedInsight = insight })
                    } else {
                        InsightCard(insight, onClick = { selectedInsight = insight })
                    }
                }
            }
        }
    }

    selectedInsight?.let { insight ->
        InsightDetailSheet(
            insight = insight,
            range = range,
            weekly = bundle.weekly,
            onClose = { selectedInsight = null },
        )
    }

    reminderMessage?.let { message ->
        AlertDialog(
            onDismissRequest = { reminderMessage = null },
            title = { Text(stringResource(R.string.reminder_alert_title)) },
            text = { Text(message) },
            confirmButton = {
                TextButton(onClick = { reminderMessage = null }) {
                    Text(stringResource(R.string.ok))
                }
            },
            containerColor = MnTheme.background,
            titleContentColor = MnTheme.textPrimary,
            textContentColor = MnTheme.textSecondary,
        )
    }
}

// MARK: - Recommendations

@Composable
private fun RecommendationsBlock(
    recommendations: List<Recommendation>,
    onAction: (RecommendationAction?) -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MnTheme.cardBackground)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            stringResource(R.string.recommendations),
            fontWeight = FontWeight.SemiBold,
            color = MnTheme.textPrimary,
        )
        recommendations.forEach { rec ->
            RecommendationRow(rec) { onAction(rec.action) }
        }
    }
}

@Composable
private fun RecommendationRow(recommendation: Recommendation, onTap: () -> Unit) {
    // iOS `RecommendationPriority`: high = 0, medium = 1, low = 2.
    val priorityColor = when (recommendation.priority) {
        0 -> MnTheme.danger
        1 -> MnTheme.streakIndicator
        else -> MnTheme.streakActiveNote
    }
    Row(
        Modifier
            .fillMaxWidth()
            .background(priorityColor.copy(alpha = 0.08f), RoundedCornerShape(10.dp))
            .clickable(onClick = onTap)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            insightIcon(recommendation.icon),
            contentDescription = null,
            tint = priorityColor,
            modifier = Modifier.size(24.dp),
        )
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                recommendation.title,
                fontWeight = FontWeight.Medium,
                color = MnTheme.textPrimary,
            )
            Text(
                recommendation.message,
                fontSize = 12.sp,
                color = MnTheme.textSecondary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (recommendation.action != null) {
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MnTheme.textSecondary,
                modifier = Modifier.size(12.dp),
            )
        }
    }
}

// MARK: - Insights header + range picker

@Composable
private fun InsightsHeader(
    bundle: Bundle,
    range: String,
    onRangeChange: (String) -> Unit,
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                stringResource(R.string.insights),
                fontWeight = FontWeight.SemiBold,
                color = MnTheme.textPrimary,
            )
            Text(rangeSubtitle(bundle, range), fontSize = 12.sp, color = MnTheme.textSecondary)
        }
        Spacer(Modifier.width(12.dp))
        RangePicker(range = range, onRangeChange = onRangeChange)
    }
}

/** iOS `rangeSubtitle`: "Last 7 Days · 42% complete" (completion insight value). */
private fun rangeSubtitle(bundle: Bundle, range: String): String {
    val completion = bundle.insights
        .firstOrNull { it.category == com.mn.android.data.StreakInsightsSource.Category.COMPLETION }
        ?.value
        ?: return rangeTitle(range)
    return "${rangeTitle(range)} · ${(completion * 100).toInt()}% complete"
}

/**
 * iOS uses a tinted `.segmented` picker; M3's SegmentedButton pulls colors
 * from the M3 scheme this app does not use, so this is the same control in
 * MnTheme colors: selected pill = streakActiveMeditation fill.
 */
@Composable
private fun RangePicker(range: String, onRangeChange: (String) -> Unit) {
    Row(
        Modifier
            .background(MnTheme.cardBackground, RoundedCornerShape(8.dp))
            .padding(2.dp),
    ) {
        listOf("last7", "last30", "last90").forEach { option ->
            val selected = option == range
            Text(
                rangeShortLabel(option),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (selected) MnTheme.buttonText else MnTheme.textSecondary,
                modifier = Modifier
                    .background(
                        if (selected) MnTheme.toolbarBackground else Color.Transparent,
                        RoundedCornerShape(6.dp),
                    )
                    .clickable { onRangeChange(option) }
                    .padding(horizontal = 12.dp, vertical = 4.dp),
            )
        }
    }
}

// MARK: - Insight cards

@Composable
private fun InsightCard(insight: Insight, onClick: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(MnTheme.cardBackground, RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(
                insightIcon(insight.icon),
                contentDescription = null,
                tint = insight.category.accent(),
                modifier = Modifier.size(12.dp),
            )
            Text(
                insight.title,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = MnTheme.textSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            Icon(
                Icons.AutoMirrored.Filled.ArrowForward,
                contentDescription = null,
                tint = MnTheme.textSecondary,
                modifier = Modifier.size(10.dp),
            )
        }
        Text(
            insight.message,
            fontSize = 12.sp,
            color = MnTheme.textPrimary,
        )
        insight.value?.let { value ->
            Box(
                Modifier
                    .fillMaxWidth()
                    .padding(top = 2.dp)
                    .height(4.dp)
                    .background(MnTheme.toolbarBackground, RoundedCornerShape(50)),
            ) {
                Box(
                    Modifier
                        .fillMaxWidth(value.coerceIn(0.0, 1.0).toFloat())
                        .height(4.dp)
                        .background(insight.category.accent(), RoundedCornerShape(50)),
                )
            }
        }
    }
}

@Composable
private fun HeatmapInsightRow(insight: Insight, onClick: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(MnTheme.cardBackground, RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(
                insightIcon(insight.icon),
                contentDescription = null,
                tint = insight.category.accent(),
                modifier = Modifier.size(12.dp),
            )
            Text(
                insight.title,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = MnTheme.textSecondary,
                modifier = Modifier.weight(1f),
            )
            Icon(
                Icons.AutoMirrored.Filled.ArrowForward,
                contentDescription = null,
                tint = MnTheme.textSecondary,
                modifier = Modifier.size(10.dp),
            )
        }
        insight.heatmap?.let { WeekdayHeatmapView(it) }
        Text(
            insight.message,
            fontSize = 12.sp,
            color = MnTheme.textPrimary,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

// MARK: - Reminder recommendation

/**
 * iOS `enableReminderForWeakestDay`: 20:00 reminder on the weakest weekday
 * (or daily). The iOS branch also checks notification authorization —
 * Android has no reminder scheduling yet (Phase 6), so this only persists
 * the settings the scheduler will read.
 */
private fun enableReminderForWeakestDay(bundle: Bundle, onMessage: (String) -> Unit) {
    val days = bundle.insights.firstOrNull { it.heatmap != null }?.heatmap?.days
    val weakestIndex = days?.indices?.minByOrNull { days[it].completionRate }
    val weekdays = if (weakestIndex != null) longArrayOf((weakestIndex + 1).toLong())
    else longArrayOf(1, 2, 3, 4, 5, 6, 7)
    SharedPrefsReminderSettingsStore.save(enabled = true, hour = 20, minute = 0, weekdays = weekdays)
    onMessage(
        if (weakestIndex != null) {
            "Reminder enabled for ${days!![weakestIndex].name}s at 20:00."
        } else {
            "Daily reminder enabled at 20:00."
        }
    )
}
