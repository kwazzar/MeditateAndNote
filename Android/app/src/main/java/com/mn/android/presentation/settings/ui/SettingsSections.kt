package com.mn.android.presentation.settings.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Air
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.VolumeDown
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.filled.Waves
import androidx.compose.material.icons.filled.WbTwilight
import androidx.compose.material3.Icon
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mn.android.R
import com.mn.android.domain.theme.model.MainTheme
import com.mn.android.infrastructure.persistence.local.settings.AnimationSettings
import com.mn.android.infrastructure.persistence.local.settings.SoundSettings
import com.mn.android.presentation.theme.ui.LocalMnThemeManager
import com.mn.android.presentation.theme.ui.MnTheme
import com.mn.android.presentation.theme.ui.MnVolumeSlider

// MARK: - Meditation Animation — iOS animationSection: segmented Rings/Path.

@Composable
internal fun AnimationSection() {
    SectionCard {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            SectionHeader(stringResource(R.string.meditation_animation), Icons.Filled.Waves)
            var animationStyle by remember { mutableStateOf(AnimationSettings.style) }
            Row(
                Modifier
                    .fillMaxWidth()
                    .background(MnTheme.cardBackground, RoundedCornerShape(8.dp))
                    .padding(2.dp),
            ) {
                listOf(AnimationSettings.RINGS to R.string.animation_rings,
                       AnimationSettings.PATH to R.string.animation_path).forEach { (option, label) ->
                    val selected = option == animationStyle
                    Text(
                        stringResource(label),
                        color = if (selected) MnTheme.buttonText else MnTheme.textSecondary,
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .weight(1f)
                            .background(
                                if (selected) MnTheme.toolbarBackground else Color.Transparent,
                                RoundedCornerShape(6.dp),
                            )
                            .clickable {
                                animationStyle = option
                                AnimationSettings.style = option
                            }
                            .padding(vertical = 6.dp),
                    )
                }
            }
        }
    }
}

// MARK: - App Theme — iOS themeSection: one row per MainTheme.

@Composable
internal fun ThemeSection() {
    SectionCard {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            SectionHeader(stringResource(R.string.app_theme), Icons.Filled.Palette)
            val themeManager = LocalMnThemeManager.current
            MainTheme.entries.forEach { theme ->
                val selected = theme == themeManager.theme
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { themeManager.select(theme) }
                        .padding(vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(
                        themeIcon(theme),
                        contentDescription = null,
                        tint = if (selected) MnTheme.streakActiveMeditation else MnTheme.textSecondary,
                        modifier = Modifier
                            .size(28.dp)
                            .background(themeSwatch(theme), CircleShape)
                            .padding(6.dp),
                    )
                    Text(
                        theme.displayName,
                        color = MnTheme.textPrimary,
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier.weight(1f),
                    )
                    if (selected) {
                        Icon(
                            Icons.Filled.Check,
                            contentDescription = null,
                            tint = MnTheme.streakActiveMeditation,
                            modifier = Modifier.size(14.dp),
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Meditation Sound Volume — iOS volumeSection.

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun VolumeSection() {
    SectionCard {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            SectionHeader(stringResource(R.string.meditation_sound_volume), Icons.Filled.VolumeUp)
            var volume by remember { mutableFloatStateOf(SoundSettings.volume) }
            Text(
                stringResource(R.string.percent_format, (volume * 100).toInt()),
                color = MnTheme.textSecondary,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.End,
            )
            // iOS UISlider: a 4pt line with a round white knob.
            MnVolumeSlider(
                value = volume,
                onValueChange = {
                    volume = it
                    SoundSettings.volume = it
                },
            )
            Row {
                Icon(
                    Icons.Filled.VolumeDown,
                    contentDescription = null,
                    tint = MnTheme.textSecondary,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(Modifier.weight(1f))
                Icon(
                    Icons.Filled.VolumeUp,
                    contentDescription = null,
                    tint = MnTheme.textSecondary,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
    }
}

/** iOS `MainTheme.swatch` — the circle behind each picker icon. */
private fun themeSwatch(theme: MainTheme): Color = when (theme) {
    MainTheme.LIQUID_GLASS -> Color(0xFFEBF5FF)
    MainTheme.BREATHING -> Color(0xFFEBF5FF)
    MainTheme.SOFT_DAWN -> Color(0xFFFFF0E0)
    MainTheme.DARK_ZEN -> Color(0xFF0F1424)
    MainTheme.OBSIDIAN -> Color(0xFF0A0D12)
}

private fun themeIcon(theme: MainTheme): ImageVector = when (theme) {
    MainTheme.LIQUID_GLASS -> Icons.Filled.WaterDrop
    MainTheme.BREATHING -> Icons.Filled.Air
    MainTheme.SOFT_DAWN -> Icons.Filled.WbTwilight
    MainTheme.DARK_ZEN -> Icons.Filled.DarkMode
    MainTheme.OBSIDIAN -> Icons.Filled.LocalFireDepartment
}
