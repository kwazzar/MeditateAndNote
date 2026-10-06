package com.mn.android.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * Compose mirror of the tokens `MainTheme` serves in
 * `MeditateAndNote/Views/Theme/MainTheme.swift`.
 *
 * Only the tokens the onboarding flow actually reads are here, and only the
 * default theme: `darkZen`, the iOS default. The theme picker does not exist on
 * Android yet, so the other four cases would be values no screen can select —
 * adding them when the picker lands is cheaper than a generator that translates
 * SwiftUI `@ViewBuilder` bodies today.
 *
 * Opacity comments record the Swift expression the hex came from, because
 * `white.opacity(0.6)` is what the Swift file says and hex is what this file
 * has to agree with.
 */
object MnTheme {

    // MainTheme.darkZen mainBackground: Color(red: 0.06, green: 0.08, blue: 0.14)
    val background = Color(0xFF0F1424)

    val textPrimary = Color(0xFFFFFFFF) // .white
    val textSecondary = Color(0x99FFFFFF) // .white.opacity(0.6)
    val iconPrimary = Color(0xFFFFFFFF) // .white
    val divider = Color(0x1AFFFFFF) // .white.opacity(0.1)

    /** `MainTheme.buttonText` — deliberately the same for every theme. */
    val buttonText = Color(0xFFFFFFFF)

    /**
     * `MainTheme.accentButton` — SwiftUI `.purple`, the one brand accent.
     * Opaque by design so nothing shows through the button.
     */
    val accentButton = Color(0xFFB052B5)

    /** `DarkZenStarfield` dots: white at 0.08 opacity, 2pt across. */
    val star = Color(0x14FFFFFF)

    /** `MainTheme.streakCellBackground` darkZen: `Color.white.opacity(0.06)`. */
    val cardBackground = Color(0x0FFFFFFF)

    /**
     * `MainTheme.streakSuccess` darkZen: `.green.opacity(0.85)`.
     * `Color.green` on iOS is UIColor.green = #009900, so alpha 0.85 → #D9.
     */
    val streakSuccess = Color(0xD9009900)

    /**
     * `MainTheme.streakActiveNote` darkZen: `.blue.opacity(0.85)`.
     * `Color.blue` on iOS is UIColor.blue = #0000FF, so alpha 0.85 → #D9.
     */
    val streakActiveNote = Color(0xD90000FF)
}
