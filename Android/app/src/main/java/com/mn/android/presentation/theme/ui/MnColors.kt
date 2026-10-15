package com.mn.android.presentation.theme.ui

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import com.mn.android.domain.theme.model.MainTheme

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
internal val DANGER_DELETE = Color(0xFFFF453A)

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

/** Built once, eagerly: five themes, pure function, no per-read allocation. */
private val THEME_COLORS: Map<MainTheme, MnColors> =
    MainTheme.entries.associateWith { buildColors(it) }

/** `MainTheme.colors` — the colour table for a theme. */
val MainTheme.colors: MnColors get() = THEME_COLORS.getValue(this)
