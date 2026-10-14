package com.mn.android.ui.streak

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
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
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Replay
import androidx.compose.material.icons.outlined.Warning
import androidx.compose.material3.Icon
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.data.StreakInsightsSource.Bundle
import com.mn.android.ui.theme.MnTheme

/**
 * Port of iOS `LifetimePatternsSection`: streak-length distribution,
 * recovery resilience, and the weekday break pattern. Range-independent —
 * stays put while the user toggles 7D/30D/90D.
 */
@Composable
internal fun LifetimePatternsSection(bundle: Bundle) {
    MnCard {
        Column(
            Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                "Lifetime Patterns",
                fontWeight = FontWeight.SemiBold,
                color = MnTheme.textPrimary,
            )

            if (bundle.distribution.totalStreaks > 0) {
                StreakDistributionCard(bundle)
            }
            if (bundle.resilience.totalRecoveries > 0) {
                ResilienceCard(bundle.resilience)
            }
            if (bundle.heatmap.days.isNotEmpty()) {
                BreakPatternCard(bundle.heatmap)
            }
        }
    }
}

// MARK: - Distribution

@Composable
private fun StreakDistributionCard(bundle: Bundle) {
    val distribution = bundle.distribution
    val maxCount = (distribution.buckets.maxOfOrNull { it.count } ?: 1).coerceAtLeast(1)

    // iOS appear animation: rows fade in, bars grow, staggered by 0.05s.
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Outlined.BarChart,
                contentDescription = null,
                tint = MnTheme.accentButton,
                modifier = Modifier.size(12.dp),
            )
            Text(
                "Streak Distribution",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = MnTheme.textSecondary,
            )
        }

        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            distribution.buckets.forEachIndexed { index, bucket ->
                val appear by animateFloatAsState(
                    targetValue = if (appeared) 1f else 0f,
                    animationSpec = tween(300, delayMillis = index * 50),
                    label = "dist$index",
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.graphicsLayer(alpha = appear),
                ) {
                    Text(
                        bucket.label,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = MnTheme.textSecondary,
                        modifier = Modifier.width(72.dp),
                    )
                    Box(
                        Modifier
                            .weight(1f)
                            .height(8.dp)
                            .background(MnTheme.toolbarBackground, RoundedCornerShape(50)),
                    ) {
                        Box(
                            Modifier
                                .fillMaxWidth(bucket.count.toFloat() / maxCount * appear)
                                .height(8.dp)
                                .background(MnTheme.accentButton, RoundedCornerShape(50)),
                        )
                    }
                    Text(
                        "${bucket.count}",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MnTheme.textPrimary,
                        modifier = Modifier.width(28.dp),
                        textAlign = androidx.compose.ui.text.style.TextAlign.End,
                    )
                }
            }
        }

        Text(distributionSummary(distribution.totalStreaks, distribution.medianLength, distribution.buckets), fontSize = 12.sp, color = MnTheme.textPrimary)
    }
}

/** iOS `distributionSummary`. */
private fun distributionSummary(
    totalStreaks: Int,
    median: Int,
    buckets: List<com.mn.android.data.StreakInsightsSource.DistributionBucket>,
): String {
    val largest = buckets.maxByOrNull { it.count }
    if (largest != null && largest.count > 0) {
        return "$totalStreaks streaks total. Most common: ${largest.label.lowercase()}. " +
            "Median: $median day${if (median == 1) "" else "s"}."
    }
    return "$totalStreaks streaks total."
}

// MARK: - Resilience

@Composable
private fun ResilienceCard(resilience: com.mn.android.data.StreakInsightsSource.Resilience) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Outlined.Replay,
                contentDescription = null,
                tint = MnTheme.streakActiveMeditation,
                modifier = Modifier.size(12.dp),
            )
            Text(
                "Resilience",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = MnTheme.textSecondary,
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            StatTile(
                label = "Avg recovery",
                value = "%.1f".format(resilience.avgRecoveryDays),
                unit = "days",
                modifier = Modifier.weight(1f),
            )
            StatTile(
                label = "Longest gap",
                value = "${resilience.longestRecoveryDays}",
                unit = "days",
                modifier = Modifier.weight(1f),
            )
            StatTile(
                label = "Recoveries",
                value = "${resilience.totalRecoveries}",
                unit = null,
                modifier = Modifier.weight(1f),
            )
        }

        if (resilience.survival.isNotEmpty()) {
            val byDay = resilience.survival.associate { it.day to it.probability }
            fun pct(day: Int) = byDay[day]?.let { "${(it * 100).toInt()}%" } ?: "—"
            Text(
                "Survival — 7d: ${pct(7)}, 14d: ${pct(14)}, 30d: ${pct(30)}",
                fontSize = 12.sp,
                color = MnTheme.textPrimary,
            )
        }
    }
}

@Composable
private fun StatTile(label: String, value: String, unit: String?, modifier: Modifier = Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(label, fontSize = 10.sp, fontWeight = FontWeight.Medium, color = MnTheme.textSecondary)
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(value, fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = MnTheme.textPrimary)
            if (unit != null) {
                Text(unit, fontSize = 10.sp, fontWeight = FontWeight.Medium, color = MnTheme.textSecondary)
            }
        }
    }
}

// MARK: - Break pattern

@Composable
private fun BreakPatternCard(heatmap: com.mn.android.data.StreakInsightsSource.Heatmap) {
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Outlined.Warning,
                contentDescription = null,
                tint = MnTheme.danger,
                modifier = Modifier.size(12.dp),
            )
            Text(
                "Break Pattern",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = MnTheme.textSecondary,
            )
        }

        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            heatmap.days.forEachIndexed { index, day ->
                val appear by animateFloatAsState(
                    targetValue = if (appeared) 1f else 0f,
                    animationSpec = tween(300, delayMillis = index * 50),
                    label = "break$index",
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.graphicsLayer(alpha = appear),
                ) {
                    Text(
                        day.name,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = MnTheme.textSecondary,
                        modifier = Modifier.width(32.dp),
                    )
                    Box(
                        Modifier
                            .weight(1f)
                            .height(8.dp)
                            .background(MnTheme.toolbarBackground, RoundedCornerShape(50)),
                    ) {
                        Box(
                            Modifier
                                .fillMaxWidth(day.breakRate.toFloat().coerceIn(0f, 1f) * appear)
                                .height(8.dp)
                                .background(MnTheme.danger, RoundedCornerShape(50)),
                        )
                    }
                    Text(
                        "${(day.breakRate * 100).toInt()}%",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MnTheme.textPrimary,
                        modifier = Modifier.width(36.dp),
                        textAlign = androidx.compose.ui.text.style.TextAlign.End,
                    )
                }
            }
        }

        val worst = heatmap.days.maxByOrNull { it.breakRate }
        Text(
            if (worst == null || worst.breakRate <= 0.0) "No breaks recorded yet."
            else "${worst.name}s account for ${(worst.breakRate * 100).toInt()}% of streak breaks.",
            fontSize = 12.sp,
            color = MnTheme.textPrimary,
        )
    }
}
