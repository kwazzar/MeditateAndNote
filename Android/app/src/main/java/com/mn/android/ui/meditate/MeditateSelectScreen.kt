package com.mn.android.ui.meditate

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AllInclusive
import androidx.compose.material.icons.outlined.Air
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Eco
import androidx.compose.material.icons.outlined.Nightlight
import androidx.compose.material.icons.outlined.Psychology
import androidx.compose.material.icons.outlined.TrackChanges
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mn.android.data.MeditationCatalog
import com.mn.android.data.MeditationSelection
import com.mn.android.data.MeditationUi
import com.mn.android.ui.theme.MnTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Compose counterpart of `MeditateSelectView` + `MeditateSelectViewModel`.
 *
 * State is a plain screen-local holder, not a `ViewModel`: the catalog loads
 * once in `LaunchedEffect` and nothing outlives the composition — the Phase 4
 * state-model choice (Kotlin mirrors state, Core does not stream) is recorded
 * in ANDROID_PORT_PLAN.
 *
 * Deliberately missing vs iOS: the Start button (its target — the breathing
 * screen — does not exist yet), the sound settings sheet (no `SoundPlayer` on
 * Android), and the 500 ms artificial load delay (a real JNI call does not need
 * help feeling slow).
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun MeditateSelectScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    var items by remember { mutableStateOf<List<MeditationUi>>(emptyList()) }
    var error by remember { mutableStateOf<String?>(null) }
    var selectedId by remember { mutableStateOf<String?>(null) }
    var infoItem by remember { mutableStateOf<MeditationUi?>(null) }

    LaunchedEffect(Unit) {
        MeditationSelection.configure(context)
        runCatching { withContext(Dispatchers.IO) { MeditationCatalog.load() } }
            .onSuccess { loaded ->
                items = loaded
                // Mirror of `MediateSelectViewModel.restoreLastSelectedMeditation`:
                // stored id if it still exists, else first entry, saved back.
                val stored = MeditationSelection.lastSelectedId
                val restored = loaded.firstOrNull { it.id == stored } ?: loaded.firstOrNull()
                selectedId = restored?.id
                if (restored != null) {
                    MeditationSelection.lastSelectedId = restored.id
                }
            }
            .onFailure { failure ->
                error = "${failure.javaClass.simpleName}: ${failure.message}"
            }
    }

    val selected = items.firstOrNull { it.id == selectedId }

    Column(
        Modifier
            .fillMaxSize()
            .background(MnTheme.background)
            .padding(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.AutoMirrored.Outlined.ArrowBack,
                    contentDescription = "Back",
                    tint = MnTheme.textPrimary,
                )
            }
            Text(
                "Meditations",
                color = MnTheme.textPrimary,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
        }

        Text(
            text = if (selected != null) "Ready to begin your journey"
            else "Choose your path to inner peace",
            color = MnTheme.textSecondary,
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp),
        )

        when {
            error != null -> Text(
                "failed: $error",
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 24.dp),
            )

            items.isEmpty() -> Text(
                "No Meditations Available",
                color = MnTheme.textPrimary,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(top = 40.dp),
            )

            else -> {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        "Available Meditations",
                        color = MnTheme.textPrimary,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        "Long press for details",
                        color = MnTheme.textSecondary,
                        style = MaterialTheme.typography.bodySmall,
                        fontStyle = FontStyle.Italic,
                    )
                }

                Spacer(Modifier.height(12.dp))

                LazyVerticalGrid(
                    columns = GridCells.Fixed(2),
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    items(items, key = { it.id }) { meditation ->
                        MeditationCard(
                            meditation = meditation,
                            isSelected = meditation.id == selectedId,
                            onSelect = {
                                selectedId = meditation.id
                                MeditationSelection.lastSelectedId = meditation.id
                            },
                            onLongPress = { infoItem = meditation },
                        )
                    }
                }
            }
        }
    }

    infoItem?.let { meditation ->
        AlertDialog(
            onDismissRequest = { infoItem = null },
            title = {
                Text(
                    meditation.title,
                    color = MnTheme.textPrimary,
                    fontWeight = FontWeight.Bold,
                )
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        "${meditation.category} · ${meditation.patternName} pattern",
                        color = MnTheme.streakActiveNote,
                        style = MaterialTheme.typography.labelMedium,
                    )
                    Text(
                        meditation.description.orEmpty(),
                        color = MnTheme.textSecondary,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = { infoItem = null }) {
                    Text("Close", color = MnTheme.accentButton)
                }
            },
            containerColor = MnTheme.background,
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun MeditationCard(
    meditation: MeditationUi,
    isSelected: Boolean,
    onSelect: () -> Unit,
    onLongPress: () -> Unit,
) {
    Column(
        Modifier
            .shadow(4.dp, RoundedCornerShape(12.dp))
            .background(
                if (isSelected) MnTheme.streakActiveNote.copy(alpha = 0.1f)
                else MnTheme.cardBackground,
                RoundedCornerShape(12.dp),
            )
            .border(
                width = if (isSelected) 2.dp else 0.dp,
                color = if (isSelected) MnTheme.streakActiveNote else MnTheme.background,
                shape = RoundedCornerShape(12.dp),
            )
            .combinedClickable(onClick = onSelect, onLongClick = onLongPress)
            .padding(12.dp)
            .height(120.dp),
    ) {
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top,
        ) {
            Icon(
                meditation.icon(),
                contentDescription = null,
                tint = MnTheme.streakActiveNote,
                modifier = Modifier.size(24.dp),
            )
            if (isSelected) {
                Icon(
                    Icons.Outlined.CheckCircle,
                    contentDescription = "Selected",
                    tint = MnTheme.streakSuccess,
                    modifier = Modifier.size(24.dp),
                )
            }
        }

        Spacer(Modifier.weight(1f))

        Text(
            meditation.title,
            color = MnTheme.textPrimary,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            maxLines = 2,
        )

        Spacer(Modifier.height(8.dp))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Outlined.Schedule,
                contentDescription = null,
                tint = MnTheme.textSecondary,
                modifier = Modifier.size(14.dp),
            )
            Spacer(Modifier.width(4.dp))
            Text(
                "${meditation.patternName} pattern",
                color = MnTheme.textSecondary,
                style = MaterialTheme.typography.labelSmall,
                maxLines = 2,
            )
        }
    }
}

/**
 * Same title-matching heuristic as `MeditationCard.meditationIcon(for:)` in
 * SwiftUI, with Material equivalents for the SF Symbols it picks. Titles are
 * domain data, so both platforms branch on the same strings.
 */
private fun MeditationUi.icon(): ImageVector {
    val lower = title.lowercase()
    return when {
        lower.contains("breath") -> Icons.Outlined.Air
        lower.contains("sleep") -> Icons.Outlined.Nightlight
        lower.contains("focus") -> Icons.Outlined.TrackChanges
        lower.contains("calm") || lower.contains("relax") -> Icons.Outlined.Eco
        lower.contains("mindful") -> Icons.Outlined.Psychology
        else -> Icons.Outlined.AllInclusive
    }
}
