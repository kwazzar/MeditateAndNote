package com.mn.android.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * Compose mirror of `MainTheme.breathingPhaseColor(_:)` for `darkZen`.
 *
 * `Color.cyan` on iOS = UIColor.cyan = #00FFFF, alpha 0.9 → #D9.
 * `Color.blue` = #0000FF → reuse `streakActiveNote`.
 * `Color.purple` = #800080, alpha 0.9 → #D9.
 * `Color.indigo` = #4B0082, alpha 0.9 → #D9.
 */
object MnBreathing {
    val inhale = Color(0xD900FFFF)
    val holdAfterInhale = Color(0xD90000FF)
    val exhale = Color(0xD9B052B5) // SwiftUI .purple = UIColor.systemPurple #B052B5
    val holdAfterExhale = Color(0xD94B40BE) // SwiftUI .indigo = #4B40BE
}