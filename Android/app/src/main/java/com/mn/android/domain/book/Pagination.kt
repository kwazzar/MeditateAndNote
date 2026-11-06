package com.mn.android.domain.book

/** The layout result of a re-pagination: how many pages, and where to land. */
data class Pagination(
    val pageCount: Int,
    val page: Int,
)
