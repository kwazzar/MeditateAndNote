package com.mn.android.presentation.theme.ui

import androidx.compose.ui.graphics.Color

/**
 * Compose mirror of `MainTheme.breathingPhaseColor(_:)`.
 *
 * iOS uses UIColor system colours: dark themes dim with `.opacity(0.9)`, light
 * themes take the light system values. The web named colours (#00FFFF/#0000FF)
 * are NOT what SwiftUI `.cyan`/`.blue` resolve to.
 */
object MnBreathing {
    // Dark (darkZen, obsidian): #64D2FF/#0A84FF/#BF5AF2/#5E5CE6 at 0.9.
    val inhaleDark = Color(0xE664D2FF)
    val holdAfterInhaleDark = Color(0xE60A84FF)
    val exhaleDark = Color(0xE6BF5AF2)
    val holdAfterExhaleDark = Color(0xE65E5CE6)

    // Light (liquidGlass, breathing, softDawn): cyan is a custom teal in iOS.
    val inhaleLight = Color(0xFF008CA6)
    val holdAfterInhaleLight = Color(0xFF007AFF)
    val exhaleLight = Color(0xFFAF52DE)
    val holdAfterExhaleLight = Color(0xFF5856D6)
}
