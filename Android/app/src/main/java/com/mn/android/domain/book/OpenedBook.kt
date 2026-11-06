package com.mn.android.domain.book

/** A book that was opened for reading: its title and where the reader lands. */
data class OpenedBook(
    val title: String,
    val pageCount: Int,
    val page: Int,
)
