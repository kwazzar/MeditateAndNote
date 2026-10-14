package com.mn.android.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Air
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * Compose port of `MainTheme.meditateIcon`
 * (`MeditateAndNote/Views/Main/MeditateButtonComponents.swift`): three stroked
 * concentric rings around a filled circle with a "wind" glyph.
 *
 * Shared by the launch loader and the Home meditate button — on iOS both read
 * the same token, and the splash hero uses the Home button's exact position so
 * the icon does not jump when the loader fades.
 *
 * The iOS `.ultraThinMaterial` fill (liquidGlass) is approximated with a
 * translucent white; the true blur is an API 31+ `RenderEffect` and not worth a
 * separate branch for one theme's hero.
 */
@Composable
fun MeditateHero(
    modifier: Modifier = Modifier,
    scale: Float = 1f,
) {
    val colors = MnTheme.colors
    val theme = LocalMnThemeManager.current.theme
    val shadowColor = colors.accentButton.copy(alpha = 0.35f)

    Box(modifier.scale(scale), contentAlignment = Alignment.Center) {
        for (i in 0..2) {
            val ringColor =
                if (theme == MainTheme.OBSIDIAN) Color.White.copy(alpha = 0.10f - i * 0.02f)
                else colors.accentButton.copy(alpha = 0.15f - i * 0.04f)
            Box(
                Modifier
                    .size((160 + i * 28).dp)
                    .border(2.dp, ringColor, CircleShape)
            )
        }

        val innerFill = when (theme) {
            MainTheme.BREATHING -> Modifier.background(
                Brush.radialGradient(
                    listOf(
                        colors.accentButton,
                        colors.accentButton.copy(alpha = 0.8f),
                        colors.accentButton.copy(alpha = 0.6f),
                    )
                )
            )
            MainTheme.SOFT_DAWN -> Modifier.background(
                Brush.linearGradient(listOf(Color(0xFFFAD9BF), Color(0xFFD9BFF2)))
            )
            MainTheme.LIQUID_GLASS -> Modifier.background(Color.White.copy(alpha = 0.1f))
            MainTheme.DARK_ZEN -> Modifier.background(Color.White.copy(alpha = 0.08f))
            MainTheme.OBSIDIAN -> Modifier.background(Color.White.copy(alpha = 0.06f))
        }

        Box(
            Modifier
                .size(140.dp)
                .shadow(16.dp, CircleShape, ambientColor = shadowColor, spotColor = shadowColor)
                .clip(CircleShape)
                .then(innerFill),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Outlined.Air,
                contentDescription = null,
                tint = colors.buttonText,
                modifier = Modifier.size(48.dp),
            )
        }
    }
}
