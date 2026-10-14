package com.mn.android.ui.meditate

import androidx.compose.foundation.background
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
import androidx.compose.material.icons.rounded.VolumeUp
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.data.SoundSettings
import com.mn.android.sound.MeditationSound
import com.mn.android.sound.SoundPlayer
import com.mn.android.ui.theme.MnTheme

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
                        contentDescription = "Close",
                        tint = MnTheme.iconPrimary,
                        modifier = Modifier.size(16.dp),
                    )
                }
            }

            Spacer(Modifier.weight(1f))

            Icon(
                Icons.Rounded.VolumeUp,
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
                        "Sound Volume",
                        color = MnTheme.textPrimary,
                        style = MaterialTheme.typography.headlineSmall,
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        "${(volume * 100).toInt()}%",
                        color = MnTheme.textSecondary,
                        style = MaterialTheme.typography.bodyMedium,
                        // Monospace digits — `monospacedDigit()` on iOS.
                        fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                    )
                }

                Slider(
                    value = volume,
                    onValueChange = {
                        volume = it
                        SoundSettings.volume = it
                    },
                    valueRange = 0f..1f,
                    colors = SliderDefaults.colors(
                        thumbColor = MnTheme.streakActiveMeditation,
                        activeTrackColor = MnTheme.streakActiveMeditation,
                    ),
                )

                Row {
                    Icon(
                        Icons.Rounded.VolumeDown,
                        contentDescription = null,
                        tint = MnTheme.textSecondary,
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(Modifier.weight(1f))
                    Icon(
                        Icons.Rounded.VolumeUp,
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
                    "Play sample",
                    color = MnTheme.buttonText,
                    style = MaterialTheme.typography.headlineSmall,
                    fontSize = 16.sp,
                )
            }

            Spacer(Modifier.weight(1f))
        }
    }
}
