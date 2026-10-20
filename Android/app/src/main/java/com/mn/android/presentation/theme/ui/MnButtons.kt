package com.mn.android.presentation.theme.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mn.android.R

/**
 * The three exit affordances of the app, in one place, so every screen shows
 * the same button.
 *
 * - [MnBackButton] — iOS `chevron.left`: a 16 pt semibold chevron in a 36×36
 *   frame, `iconPrimary`, no chrome around it.
 * - [MnCloseButton] — iOS `xmark`: a 16 pt X in a 32 pt `toolbarBackground`
 *   circle.
 * - [MnDoneButton] — the bordered "Done" capsule of the streak screens.
 */
@Composable
fun MnBackButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier
            .size(36.dp)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
            contentDescription = stringResource(R.string.back),
            tint = MnTheme.iconPrimary,
            modifier = Modifier.size(24.dp),
        )
    }
}

/** iOS `xmark` in a `toolbarBackground` circle — the close button of the
 *  breathing screen and of the sound sheet. */
@Composable
fun MnCloseButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier
            .size(32.dp)
            .clip(CircleShape)
            .background(MnTheme.toolbarBackground)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = Icons.Rounded.Close,
            contentDescription = stringResource(R.string.close),
            tint = MnTheme.iconPrimary,
            modifier = Modifier.size(16.dp),
        )
    }
}

/** The bordered "Done" capsule — the exit of the streak detail screen and of
 *  the streak sheets. */
@Composable
fun MnDoneButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier
            .clip(CircleShape)
            .border(1.dp, MnTheme.divider, CircleShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 8.dp),
    ) {
        Text(
            stringResource(R.string.done),
            color = MnTheme.textPrimary,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Medium,
        )
    }
}
