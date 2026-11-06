package com.mn.android.domain.reader

/**
 * The reader's appearance preferences: type size, paper theme, scroll mode.
 *
 * UI state, not domain state — the paper palette and the type size are
 * presentation choices. The iOS side keeps the same values in `ReaderSettings`.
 */
interface ReaderSettings {
    /** Font size in sp. */
    fun fontSize(): Float

    fun setFontSize(size: Float)

    /** Paper theme name: "light", "sepia" or "dark". */
    fun paper(): String

    fun setPaper(name: String)

    /** True = continuous vertical scrolling, false = page by page. */
    fun scrollMode(): Boolean

    fun setScrollMode(enabled: Boolean)
}
