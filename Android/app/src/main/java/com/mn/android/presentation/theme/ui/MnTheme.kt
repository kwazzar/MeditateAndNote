package com.mn.android.presentation.theme.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.mn.android.domain.theme.model.MainTheme
import com.mn.android.infrastructure.persistence.local.settings.MnThemeStore
import kotlin.random.Random

// MARK: - Theme plumbing

/** Active theme colours. Defaults to darkZen, the iOS default, outside a provider. */
val LocalMnColors = staticCompositionLocalOf { MainTheme.DARK_ZEN.colors }

val LocalMnThemeManager = staticCompositionLocalOf<MnThemeManager> {
    error("No MnThemeManager provided — wrap the tree in MnThemeProvider")
}

/** Holds the selected [MainTheme]; mirrors iOS `ThemeManager`. */
@Stable
class MnThemeManager(initial: MainTheme) {
    var theme: MainTheme by mutableStateOf(initial)
        private set

    fun select(theme: MainTheme) {
        this.theme = theme
        MnThemeStore.selected = theme
    }
}

@Composable
fun rememberMnThemeManager(): MnThemeManager {
    val context = LocalContext.current
    return remember {
        MnThemeStore.configure(context)
        MnThemeManager(MnThemeStore.selected)
    }
}

@Composable
fun MnThemeProvider(manager: MnThemeManager, content: @Composable () -> Unit) {
    CompositionLocalProvider(
        LocalMnColors provides manager.theme.colors,
        LocalMnThemeManager provides manager,
        content = content,
    )
}

/**
 * The theme-aware token surface. Same names as the old flat object, so existing
 * `MnTheme.textPrimary` reads keep working and now follow the active theme.
 */
object MnTheme {
    val colors: MnColors @Composable @ReadOnlyComposable get() = LocalMnColors.current

    val background: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.background
    val textPrimary: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.textPrimary
    val textSecondary: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.textSecondary
    val iconPrimary: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.iconPrimary
    val toolbarBackground: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.toolbarBackground
    val divider: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.divider
    val editorBackground: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.editorBackground
    val cardBackground: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.cardBackground
    val streakSuccess: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.streakSuccess
    val streakActiveMeditation: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.streakActiveMeditation
    val streakActiveNote: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.streakActiveNote
    val streakMuted: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.streakMuted
    val streakIndicator: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.streakIndicator
    val danger: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.danger
    val star: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.star

    /** `MainTheme.buttonText` — deliberately white in every theme. */
    val buttonText: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.buttonText

    /** `MainTheme.accentButton` — one opaque brand accent for every theme. */
    val accentButton: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.accentButton

    /** `MainTheme.accentColor` == `accentButton`. */
    val accentColor: Color @Composable @ReadOnlyComposable get() = LocalMnColors.current.accentButton

    /** Destructive tint (`delete`). */
    val deleteRed: Color @Composable @ReadOnlyComposable get() = DANGER_DELETE
}

// MARK: - Background

/**
 * `MainTheme.mainBackground`: the active theme's gradient (or solid + starfield
 * for darkZen). Draw once at a screen root behind the content.
 */
@Composable
fun MnBackground(modifier: Modifier = Modifier) {
    val colors = LocalMnColors.current
    val brush = when {
        colors.gradient.size == 1 -> Brush.linearGradient(listOf(colors.gradient[0], colors.gradient[0]))
        colors.gradientDiagonal -> Brush.linearGradient(colors.gradient)
        else -> Brush.verticalGradient(colors.gradient)
    }
    Box(modifier.fillMaxSize().background(brush)) {
        if (colors.useStarfield) {
            Starfield(Modifier.fillMaxSize())
        }
    }
}

/**
 * `DarkZenStarfield`: 40 fixed-size dots at white 0.08.
 *
 * Positions are generated once per composition, the same way the SwiftUI
 * version generates them in `onAppear` and not on every `body` call — otherwise
 * the stars would jump on each recomposition.
 */
@Composable
fun Starfield(modifier: Modifier = Modifier) {
    val color = MnTheme.star
    val stars = remember { List(40) { Random.nextFloat() to Random.nextFloat() } }
    Canvas(modifier) {
        stars.forEach { (x, y) ->
            drawCircle(
                color = color,
                radius = 1.dp.toPx(),
                center = Offset(x * size.width, y * size.height),
            )
        }
    }
}
