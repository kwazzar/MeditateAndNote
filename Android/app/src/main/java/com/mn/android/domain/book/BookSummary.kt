package com.mn.android.domain.book

/**
 * One book in the library: what the grid shows.
 *
 * The reader keeps the full document in Swift; the library only ever needs
 * these five fields, so the port carries a flat record instead of the
 * document.
 */
data class BookSummary(
    val id: BookId,
    val title: String,
    val author: String,
    /** The wire format tag: "fb2", "epub" or "txt". */
    val format: String,
    /** Reading progress in per mille (0..1000). */
    val progressPerMille: Int,
)
