package com.mn.android.domain.book

/**
 * The box the pagination engine lays a book out in.
 *
 * Swift paginates in pixels, so the width and the height are px and the font
 * size is px too (the reader converts sp through the Compose density, which
 * carries the system font scale).
 */
data class ReaderLayout(
    val fontSize: Double,
    val width: Double,
    val height: Double,
    /**
     * How much wider than the renderer paints the engine may wrap at: the two
     * measure text slightly differently, so the reader measures a probe string
     * both ways and hands the ratio over.
     */
    val widthScale: Double,
)
