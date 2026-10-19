package com.mn.android.presentation.theme.ui

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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.mn.android.domain.theme.model.MainTheme

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
    pressed: Boolean = false,
) {
    val colors = MnTheme.colors
    val theme = LocalMnThemeManager.current.theme
    // iOS `MeditateThemeButtonStyle`: the pressed state scales the hero down
    // (and dims it, or glows it for darkZen) with `.easeInOut(duration: 0.15)`.
    // liquidGlass is the one theme iOS leaves untouched.
    val pressScale = when (theme) {
        MainTheme.BREATHING -> if (pressed) 0.92f else 1f
        MainTheme.SOFT_DAWN -> if (pressed) 0.95f else 1f
        MainTheme.DARK_ZEN -> if (pressed) 0.94f else 1f
        MainTheme.OBSIDIAN -> if (pressed) 0.94f else 1f
        MainTheme.LIQUID_GLASS -> 1f
    }
    val pressAlpha = when (theme) {
        MainTheme.BREATHING -> if (pressed) 0.85f else 1f
        MainTheme.SOFT_DAWN -> if (pressed) 0.9f else 1f
        MainTheme.OBSIDIAN -> if (pressed) 0.9f else 1f
        else -> 1f
    }
    // iOS per-theme shadow: darkZen/obsidian/liquidGlass use `dividerColor`
    // (a barely-visible white glow), breathing uses accent 0.35, softDawn
    // streakIndicator 0.2. The default black shadow would flatten the dark
    // themes; the per-theme color is what gives the iOS halo.
    val shadowColor = when (theme) {
        MainTheme.BREATHING -> colors.accentButton.copy(alpha = 0.35f)
        MainTheme.SOFT_DAWN -> colors.streakIndicator.copy(alpha = 0.2f)
        else -> colors.divider
    }
    // iOS only gives the two light themes a visible halo; darkZen/obsidian's
    // `dividerColor` shadow is a barely-visible white glow that the emulator
    // renders as a polygonal artifact, so it is dropped for dark themes.
    val shadowElevation = when (theme) {
        MainTheme.BREATHING -> 24.dp
        MainTheme.SOFT_DAWN -> 16.dp
        else -> 0.dp
    }

    Box(
        modifier
            .scale(scale)
            .graphicsLayer {
                scaleX = pressScale
                scaleY = pressScale
                alpha = pressAlpha
            },
        contentAlignment = Alignment.Center,
    ) {
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
                .shadow(shadowElevation, CircleShape, ambientColor = shadowColor, spotColor = shadowColor)
                .clip(CircleShape)
                .then(innerFill),
            contentAlignment = Alignment.Center,
        ) {
            // 56dp, not the iOS 48pt: Material's Air glyph carries ~8dp of
            // viewport padding, so 48dp drew visibly smaller than the SF Symbol.
            Icon(
                Icons.Outlined.Air,
                contentDescription = null,
                tint = colors.buttonText,
                modifier = Modifier.size(56.dp),
            )
        }
    }
}
