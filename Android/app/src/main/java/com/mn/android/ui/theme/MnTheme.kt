package com.mn.android.ui.theme

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
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
import com.mn.android.data.MnThemeStore
import kotlin.random.Random

/**
 * Compose mirror of `MainTheme` in
 * `MeditateAndNote/Views/Theme/MainTheme.swift`.
 *
 * The Swift side is the source of truth: five themes, each a table of tokens,
 * plus a `mainBackground` (gradient or solid + optional starfield). This file
 * keeps the same five themes and the same token values so a theme picked on one
 * platform renders the same way on the other. Opacity comments record the Swift
 * expression each hex came from, because `white.opacity(0.6)` is what the Swift
 * file says and hex is what this file has to agree with.
 *
 * [MnTheme] stays the call-site name (`MnTheme.textPrimary`), but its getters now
 * read the active theme from [LocalMnColors] instead of a fixed darkZen table —
 * so every existing token read becomes theme-aware with no call-site churn.
 */

enum class MainTheme(
    val storageKey: String,
    val displayName: String,
    /** SF Symbol name on iOS; the Compose picker maps it to a Material icon. */
    val systemIconName: String,
) {
    LIQUID_GLASS("liquidGlass", "Liquid Glass", "drop.fill"),
    BREATHING("breathing", "Breathing", "wind"),
    SOFT_DAWN("softDawn", "Soft Dawn", "sunrise.fill"),
    DARK_ZEN("darkZen", "Dark Zen", "moon.stars.fill"),
    OBSIDIAN("obsidian", "Obsidian", "flame.fill"),
    ;

    val isDark: Boolean get() = this == DARK_ZEN || this == OBSIDIAN

    val colors: MnColors by lazy { buildColors(this) }

    companion object {
        /** `ThemeManager` key is `selectedMainTheme`; unknown values fall back to darkZen. */
        fun fromStorageKey(key: String?): MainTheme =
            entries.firstOrNull { it.storageKey == key } ?: DARK_ZEN
    }
}

/**
 * All colours a theme serves. `MainTheme.swift` splits these across separate
 * computed properties; one immutable table is cheaper to pass through a
 * CompositionLocal and impossible to read half-updated.
 */
@Immutable
data class MnColors(
    /** One stop = solid fill; more = gradient. */
    val gradient: List<Color>,
    /** `false` vertical (SwiftUI `.top`→`.bottom`); `true` diagonal. */
    val gradientDiagonal: Boolean,
    val useStarfield: Boolean,
    val isDark: Boolean,
    val textPrimary: Color,
    val textSecondary: Color,
    val iconPrimary: Color,
    val toolbarBackground: Color,
    val divider: Color,
    val editorBackground: Color,
    val streakSuccess: Color,
    val streakActiveMeditation: Color,
    val streakActiveNote: Color,
    val streakMuted: Color,
    val cardBackground: Color,
    val buttonText: Color,
    val accentButton: Color,
    val streakIndicator: Color,
    val danger: Color,
    val star: Color,
) {
    /** `MainTheme.mainBackground` base colour, and the solid fill for one-stop themes. */
    val background: Color get() = gradient.first()
}

private val GREEN = Color(0xFF009900)        // UIColor.green
private val BLUE = Color(0xFF0000FF)         // UIColor.blue
private val PURPLE = Color(0xFF800080)       // UIColor.purple
private val ORANGE = Color(0xFFFF9500)       // UIColor.orange
private val RED = Color(0xFFFF0000)          // UIColor.red
private val GRAY = Color(0xFF808080)         // UIColor.gray
private val WHITE = Color(0xFFFFFFFF)
private val BLACK = Color(0xFF000000)

// .opacity() variants, pre-multiplied: SwiftUI dark themes dim the same UIColor.
private val GREEN_85 = Color(0xD9009900)
private val BLUE_85 = Color(0xD90000FF)
private val PURPLE_85 = Color(0xD9800080)
private val ORANGE_75 = Color(0xBFFF9500)
private val RED_80 = Color(0xCCFF0000)

private val WHITE_60 = Color(0x99FFFFFF)
private val WHITE_20 = Color(0x33FFFFFF)
private val WHITE_10 = Color(0x1AFFFFFF)
private val WHITE_08 = Color(0x14FFFFFF)
private val WHITE_06 = Color(0x0FFFFFFF)
private val WHITE_05 = Color(0x0DFFFFFF)

private val BLACK_60 = Color(0x99000000)
private val BLACK_10 = Color(0x1A000000)
private val BLACK_04 = Color(0x0A000000)

private val GRAY_35 = Color(0x59808080)

/** `MainTheme.accentButton` — one opaque brand accent, identical in every theme. */
private val ACCENT = Color(0xFFB052B5)

/** Destructive tint (`delete`), constant across themes. */
private val DANGER_DELETE = Color(0xFFFF453A)

private fun buildColors(theme: MainTheme): MnColors {
    // Tokens shared by the two "plain light" themes (liquidGlass, breathing).
    val lightToolbar = WHITE_10
    return when (theme) {
        MainTheme.LIQUID_GLASS -> lightColors(
            gradient = listOf(Color(0xFFEBF5FF), Color(0xFFE0EDFA)),
            diagonal = false,
            toolbarBackground = lightToolbar,
            editorBackground = WHITE_10,
            cardBackground = WHITE_06,
        )

        MainTheme.BREATHING -> lightColors(
            gradient = listOf(Color(0xFFE6F7F5), Color(0xFFDBF0F7)),
            diagonal = false,
            toolbarBackground = lightToolbar,
            editorBackground = WHITE_10,
            cardBackground = WHITE_06,
        )

        // softDawn: light, but its toolbar/divider/editor/card sit on dark tints.
        MainTheme.SOFT_DAWN -> lightColors(
            gradient = listOf(Color(0xFFFFF0E0), Color(0xFFF2E6FA), Color(0xFFE0EDFA)),
            diagonal = true,
            toolbarBackground = BLACK_10,
            editorBackground = BLACK_10,
            cardBackground = BLACK_04,
        )

        MainTheme.DARK_ZEN -> darkColors(
            gradient = listOf(Color(0xFF0F1424)),
            diagonal = false,
            useStarfield = true,
        )

        MainTheme.OBSIDIAN -> darkColors(
            gradient = listOf(Color(0xFF0A0D12), Color(0xFF050508)),
            diagonal = true,
            useStarfield = false,
        )
    }
}

private fun lightColors(
    gradient: List<Color>,
    diagonal: Boolean,
    toolbarBackground: Color,
    editorBackground: Color,
    cardBackground: Color,
) = MnColors(
    gradient = gradient,
    gradientDiagonal = diagonal,
    useStarfield = false,
    isDark = false,
    textPrimary = BLACK,          // .primary
    textSecondary = BLACK_60,     // .secondary
    iconPrimary = BLACK,          // .primary
    toolbarBackground = toolbarBackground,
    divider = BLACK_10,           // .black.opacity(0.1)
    editorBackground = editorBackground,
    streakSuccess = GREEN,        // .green
    streakActiveMeditation = PURPLE,
    streakActiveNote = BLUE,
    streakMuted = GRAY_35,        // .gray.opacity(0.35)
    cardBackground = cardBackground,
    buttonText = WHITE,           // .white
    accentButton = ACCENT,
    streakIndicator = ORANGE,     // .orange
    danger = RED,                 // .red
    star = WHITE_08,              // unused without starfield
)

private fun darkColors(
    gradient: List<Color>,
    diagonal: Boolean,
    useStarfield: Boolean,
) = MnColors(
    gradient = gradient,
    gradientDiagonal = diagonal,
    useStarfield = useStarfield,
    isDark = true,
    textPrimary = WHITE,
    textSecondary = WHITE_60,     // .white.opacity(0.6)
    iconPrimary = WHITE,
    toolbarBackground = WHITE_10, // .white.opacity(0.1)
    divider = WHITE_10,           // .white.opacity(0.1)
    editorBackground = WHITE_05,  // .white.opacity(0.05)
    streakSuccess = GREEN_85,     // .green.opacity(0.85)
    streakActiveMeditation = PURPLE_85,
    streakActiveNote = BLUE_85,
    streakMuted = WHITE_20,       // .white.opacity(0.2)
    cardBackground = WHITE_06,    // .white.opacity(0.06)
    buttonText = WHITE,
    accentButton = ACCENT,
    streakIndicator = ORANGE_75,  // .orange.opacity(0.75)
    danger = RED_80,              // .red.opacity(0.8)
    star = WHITE_08,              // .white.opacity(0.08)
)

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
