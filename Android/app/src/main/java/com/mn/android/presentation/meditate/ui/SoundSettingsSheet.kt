package com.mn.android.presentation.meditate.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.VolumeDown
import androidx.compose.material.icons.filled.VolumeDown
import androidx.compose.material.icons.rounded.VolumeUp
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.infrastructure.persistence.local.settings.SoundSettings
import com.mn.android.infrastructure.platform.sound.MeditationSound
import com.mn.android.infrastructure.platform.sound.SoundPlayer
import com.mn.android.presentation.theme.ui.MnTheme
import com.mn.android.presentation.theme.ui.MnVolumeSlider
import androidx.compose.ui.res.stringResource
import com.mn.android.R

/**
 * Port of iOS `SoundSettingsSheet`: ~360 pt sheet with a volume slider
 * (persisted through [SoundSettings]) and a sample playback button
 * ([SoundPlayer]).
 *
 * The volume lives in screen-local Compose state and writes through to
 * `SoundSettings` on every change — the Kotlin mirror of `@Bindable` +
 * `didSet` persistence on iOS.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun SoundSettingsSheet(onDismiss: () -> Unit) {
    var volume by remember { mutableFloatStateOf(SoundSettings.volume) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MnTheme.background,
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .height(360.dp)
                .padding(24.dp)
        ) {
            Row {
                Spacer(Modifier.weight(1f))
                Box(
                    Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(MnTheme.toolbarBackground)
                        .clickable(onClick = onDismiss),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Rounded.Close,
                        contentDescription = stringResource(R.string.close),
                        tint = MnTheme.iconPrimary,
                        modifier = Modifier.size(16.dp),
                    )
                }
            }

            Spacer(Modifier.weight(1f))

            Icon(
                // iOS `speaker.wave.2.fill` — filled, not the outlined glyph.
                Icons.Filled.VolumeUp,
                contentDescription = null,
                tint = MnTheme.streakActiveMeditation,
                modifier = Modifier
                    .padding(bottom = 8.dp)
                    .size(44.dp)
                    .align(Alignment.CenterHorizontally),
            )

            // Volume card — `editorBackground`, 16 pt corners, padding 20.
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(MnTheme.editorBackground, RoundedCornerShape(16.dp))
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Row {
                    Text(
                        stringResource(R.string.sound_volume),
                        color = MnTheme.textPrimary,
                        // iOS `.font(.headline)` = 17pt semibold.
                        fontSize = 17.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        stringResource(R.string.percent_format, (volume * 100).toInt()),
                        color = MnTheme.textSecondary,
                        // iOS `.font(.subheadline)` = 15pt.
                        fontSize = 15.sp,
                        // Monospace digits — `monospacedDigit()` on iOS.
                        fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                    )
                }

                // iOS UISlider: a 4pt line with a round white knob.
                MnVolumeSlider(
                    value = volume,
                    onValueChange = {
                        volume = it
                        SoundSettings.volume = it
                    },
                    knobSize = 22.dp,
                )

                Row {
                    // iOS `speaker.fill` / `speaker.wave.3.fill` — both filled.
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

            Spacer(Modifier.height(16.dp))

            Button(
                onClick = { SoundPlayer.play(MeditationSound.PHASE_INHALE) },
                colors = ButtonDefaults.buttonColors(containerColor = MnTheme.accentButton),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(
                    Icons.Rounded.GraphicEq,
                    contentDescription = null,
                    tint = MnTheme.buttonText,
                    modifier = Modifier.size(20.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    stringResource(R.string.play_sample),
                    color = MnTheme.buttonText,
                    style = MaterialTheme.typography.headlineSmall,
                    fontSize = 16.sp,
                )
            }

            Spacer(Modifier.weight(1f))
        }
    }
}
