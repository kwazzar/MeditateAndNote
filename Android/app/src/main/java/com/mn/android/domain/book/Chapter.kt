package com.mn.android.domain.book

/** One entry of the table of contents. */
data class Chapter(
    val chapter: Int,
    val title: String,
    val page: Int,
)
