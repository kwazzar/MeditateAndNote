package com.mn.android.domain.book

/**
 * Where in a book something sits.
 *
 * Page-independent on purpose: the reader resolves the position against the
 * current layout, so a font change keeps the mark on the same passage. Swift's
 * `ReadingPosition`.
 */
data class ReadingPosition(
    val chapter: Int,
    val block: Int,
    val offset: Int,
)
