package com.mn.android.presentation.notes.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.R
import com.mn.android.data.NoteInsightsSource
import com.mn.android.presentation.theme.ui.MnTheme

/**
 * Port of the iOS `NoteInsightsSection`: a collapsible block above the note
 * list with the aggregate top themes and the freshest per-note summaries.
 *
 * Hidden while there is nothing to show — the section appears with the first
 * insight, whether it came from the stored pass or from the heuristic one.
 */
@Composable
internal fun NoteInsightsSection(
    insights: List<NoteInsightsSource.Insight>,
    themes: List<String>,
    isLoading: Boolean,
    error: String?,
    onRefresh: () -> Unit,
) {
    var isExpanded by remember { mutableStateOf(true) }

    if (insights.isEmpty()) {
        if (isLoading) LoadingState() else if (error != null) ErrorState()
        return
    }

    Column(
        Modifier
            .fillMaxWidth()
            .background(MnTheme.cardBackground, RoundedCornerShape(12.dp))
            .border(1.dp, MnTheme.divider, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        InsightsHeader(
            isExpanded = isExpanded,
            isLoading = isLoading,
            onToggle = { isExpanded = !isExpanded },
            onRefresh = onRefresh,
        )
        if (error != null) {
            Text(
                stringResource(R.string.note_insights_error),
                fontSize = 12.sp,
                color = MnTheme.textSecondary,
            )
        }
        if (isExpanded) {
            if (themes.isNotEmpty()) ThemeChips(themes)
            insights.take(3).forEach { InsightCard(it) }
        }
    }
}

// MARK: - Header

@Composable
private fun InsightsHeader(
    isExpanded: Boolean,
    isLoading: Boolean,
    onToggle: () -> Unit,
    onRefresh: () -> Unit,
) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            stringResource(R.string.note_insights_title),
            fontWeight = FontWeight.SemiBold,
            color = MnTheme.textPrimary,
            modifier = Modifier
                .weight(1f)
                .clickable(onClick = onToggle),
        )
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(16.dp),
                strokeWidth = 2.dp,
                color = MnTheme.textPrimary,
            )
        } else {
            IconButton(onClick = onRefresh) {
                Icon(
                    Icons.Filled.Refresh,
                    contentDescription = stringResource(R.string.note_insights_refresh),
                    tint = MnTheme.textPrimary.copy(alpha = 0.7f),
                    modifier = Modifier.size(18.dp),
                )
            }
        }
        Icon(
            if (isExpanded) Icons.Filled.ExpandMore else Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = MnTheme.textPrimary.copy(alpha = 0.6f),
            modifier = Modifier.size(18.dp),
        )
    }
}

// MARK: - Themes

@Composable
private fun ThemeChips(themes: List<String>) {
    Row(
        Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        themes.forEach { theme ->
            Text(
                theme,
                fontSize = 12.sp,
                color = MnTheme.textPrimary,
                modifier = Modifier
                    .background(MnTheme.textPrimary.copy(alpha = 0.1f), RoundedCornerShape(percent = 50))
                    .padding(horizontal = 10.dp, vertical = 4.dp),
            )
        }
    }
}

// MARK: - Insight card

@Composable
private fun InsightCard(insight: NoteInsightsSource.Insight) {
    Column(Modifier.fillMaxWidth()) {
        if (insight.summary.isNotEmpty()) {
            Text(
                insight.summary,
                fontSize = 14.sp,
                color = MnTheme.textPrimary,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (insight.tags.isNotEmpty()) {
            Text(
                insight.tags.joinToString(" ") { "#$it" },
                fontSize = 12.sp,
                color = MnTheme.textPrimary.copy(alpha = 0.6f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        HorizontalDivider(color = MnTheme.divider)
    }
}

// MARK: - Loading

@Composable
private fun LoadingState() {
    Row(
        Modifier
            .fillMaxWidth()
            .background(MnTheme.cardBackground, RoundedCornerShape(12.dp))
            .border(1.dp, MnTheme.divider, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CircularProgressIndicator(
            modifier = Modifier.size(16.dp),
            strokeWidth = 2.dp,
            color = MnTheme.textPrimary,
        )
        Spacer(Modifier.width(8.dp))
        Text(
            stringResource(R.string.note_insights_loading),
            fontSize = 14.sp,
            color = MnTheme.textSecondary,
        )
    }
}

// MARK: - Error

/** The pass failed and there is nothing to show instead. */
@Composable
private fun ErrorState() {
    Row(
        Modifier
            .fillMaxWidth()
            .background(MnTheme.cardBackground, RoundedCornerShape(12.dp))
            .border(1.dp, MnTheme.divider, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            stringResource(R.string.note_insights_error),
            fontSize = 14.sp,
            color = MnTheme.textSecondary,
        )
    }
}
