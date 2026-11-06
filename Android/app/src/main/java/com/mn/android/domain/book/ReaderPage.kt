package com.mn.android.domain.book

/** One paginated page: the lines to draw and where each of them starts. */
data class ReaderPage(
    val lines: List<String>,
    val positions: List<ReadingPosition>,
    /** How far through the book the page is, 0..1. */
    val progress: Double,
)
