package com.mn.android.domain.reader

/**
 * Measures text the way the pagination engine does.
 *
 * The engine lives in the shared Core package and asks the platform for the
 * width of every word; on Android that is `android.graphics.Paint`. Swift's
 * `TextMeasurer`.
 */
interface TextMeasurer {
    /** The width of [text] at [fontSize], in px. */
    fun measure(text: String, fontSize: Double): Double

    /** The line height at [fontSize], in px. */
    fun lineHeight(fontSize: Double): Double
}
