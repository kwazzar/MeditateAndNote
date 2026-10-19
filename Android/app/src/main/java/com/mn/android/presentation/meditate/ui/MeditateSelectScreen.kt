package com.mn.android.presentation.meditate.ui

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AllInclusive
import androidx.compose.material.icons.outlined.Air
import androidx.compose.material.icons.outlined.BlurCircular
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Eco
import androidx.compose.material.icons.outlined.Nightlight
import androidx.compose.material.icons.outlined.Psychology
import androidx.compose.material.icons.outlined.TrackChanges
import androidx.compose.material.icons.rounded.VolumeUp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mn.android.R
import com.mn.android.infrastructure.persistence.local.meditation.MeditationCatalog
import com.mn.android.infrastructure.persistence.local.meditation.MeditationSelection
import com.mn.android.domain.meditation.model.MeditationUi
import com.mn.android.presentation.theme.ui.MnBackground
import com.mn.android.presentation.theme.ui.MnTheme
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
 * Deliberately missing vs iOS: the 500 ms artificial load delay (a real JNI
 * call does not need help feeling slow) and haptic feedback on long-press.
 */
@OptIn(ExperimentalFoundationApi::class, androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun MeditateSelectScreen(
    onStartMeditation: (String) -> Unit = {},
) {
    val context = LocalContext.current
    var items by remember { mutableStateOf<List<MeditationUi>>(emptyList()) }
    var error by remember { mutableStateOf<String?>(null) }
    var selectedId by remember { mutableStateOf<String?>(null) }
    var infoItem by remember { mutableStateOf<MeditationUi?>(null) }
    var showSoundSettings by remember { mutableStateOf(false) }

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

    Box(Modifier.fillMaxSize()) {
        MnBackground()
        Column(
            Modifier
                .fillMaxSize()
                .padding(16.dp),
        ) {
            // iOS headerSection: `selectedMeditation?.title` in `.largeTitle` bold,
            // centered, with no back affordance — this screen is the Meditations tab.
            Text(
                selected?.title ?: stringResource(R.string.meditate_title_fallback),
                color = MnTheme.textPrimary,
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                maxLines = 2,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 24.dp),
            )

            Text(
                text = if (selected != null) stringResource(R.string.meditate_subtitle_ready)
                else stringResource(R.string.meditate_subtitle_choose),
                color = MnTheme.textSecondary,
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp, bottom = 8.dp),
            )

        when {
            error != null -> Text(
                stringResource(R.string.load_failed, error ?: ""),
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 24.dp),
            )

            items.isEmpty() -> Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 40.dp),
            ) {
                Icon(
                    Icons.Outlined.Nightlight,
                    contentDescription = null,
                    tint = MnTheme.textSecondary,
                    modifier = Modifier.size(60.dp),
                )
                Spacer(Modifier.height(12.dp))
                Text(
                    stringResource(R.string.no_meditations_available),
                    color = MnTheme.textPrimary,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Medium,
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    stringResource(R.string.check_back_later),
                    color = MnTheme.textSecondary,
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center,
                )
            }

            else -> {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        stringResource(R.string.available_meditations),
                        color = MnTheme.textPrimary,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        stringResource(R.string.long_press_for_details),
                        color = MnTheme.textSecondary,
                        style = MaterialTheme.typography.bodySmall,
                        fontStyle = FontStyle.Italic,
                    )
                    Spacer(Modifier.width(8.dp))
                    // iOS: speaker.wave.2.fill in a toolbarBackground circle.
                    Box(
                        Modifier
                            .size(32.dp)
                            .clip(CircleShape)
                            .background(MnTheme.toolbarBackground)
                            .clickable { showSoundSettings = true },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Rounded.VolumeUp,
                            contentDescription = stringResource(R.string.sound_settings),
                            tint = MnTheme.textPrimary,
                            modifier = Modifier.size(16.dp),
                        )
                    }
                }

                Spacer(Modifier.height(12.dp))

                LazyVerticalGrid(
                    columns = GridCells.Fixed(2),
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                    modifier = Modifier.weight(1f),
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

                Spacer(Modifier.height(16.dp))

                androidx.compose.material3.Button(
                    onClick = {
                        selectedId?.let { onStartMeditation(it) }
                    },
                    enabled = selectedId != null,
                    colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                        containerColor = MnTheme.accentButton,
                    ),
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                    shape = RoundedCornerShape(12.dp),
                ) {
                    Text(
                        stringResource(R.string.meditate_start),
                        color = MnTheme.buttonText,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }
        }
    }

    infoItem?.let { meditation ->
        ModalBottomSheet(
            onDismissRequest = { infoItem = null },
            containerColor = MnTheme.background,
        ) {
            Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    meditation.title,
                    color = MnTheme.textPrimary,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                )
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
                Spacer(Modifier.height(8.dp))
                Button(
                    onClick = { infoItem = null },
                    colors = ButtonDefaults.buttonColors(containerColor = MnTheme.accentButton),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(stringResource(R.string.close), color = MnTheme.buttonText)
                }
                Spacer(Modifier.height(24.dp))
            }
        }
    }

    if (showSoundSettings) {
        SoundSettingsSheet(onDismiss = { showSoundSettings = false })
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
            .padding(16.dp)
            .heightIn(min = 120.dp),
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
                    contentDescription = null,
                    tint = MnTheme.streakSuccess,
                    modifier = Modifier.size(24.dp),
                )
            }
        }

        Spacer(Modifier.height(8.dp))

        Text(
            meditation.title,
            color = MnTheme.textPrimary,
            style = MaterialTheme.typography.titleMedium,
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
                stringResource(R.string.pattern_suffix, meditation.patternName),
                color = MnTheme.textSecondary,
                style = MaterialTheme.typography.labelSmall,
                maxLines = 2,
            )
        }

        // iOS: title/pattern sit directly under the icon, the slack stays at the bottom.
        Spacer(Modifier.weight(1f))
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
        else -> Icons.Outlined.BlurCircular  // SF "circle.dotted"
    }
}
